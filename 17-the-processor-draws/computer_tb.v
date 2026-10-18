// Chapter 17, test bench for the whole computer, with the program of the
// board, draw.s. The test bench presses S2 at the start, as you can on the
// board, so that the program does not wait between its steps: the 32 steps
// of lines then take a few million cycles instead of eight seconds. It
// watches every write, and says when each step begins. When the LEDs show 33,
// the drawing is done: it compares the bitmap, byte by byte, with a picture
// of its own, drawn with the same lines and the same algorithm, but with
// plain integers: no tables, no numbers in two bytes. Then it lets
// the program paint the first new colors, and checks them.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         reset = 0;
    reg         s2    = 0;      // button S2, wired to NMI as on the board
    reg         s2_pressed = 0; // it is pressed once,
    integer     pressed_at = 0; // at this cycle
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;

    // The timer from chapter 3 says when the processor moves. 2 is as fast
    // as the bus allows, as on the board.
    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk            (clk),
        .reset          (reset),
        .step           (step),
        .irq            (1'b0),     // nothing asks for IRQ
        .nmi            (s2),
        .leds           (leds),
        .address        (address),
        .data_in        (data_in),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (13'd0),    // no display in this test bench
        .bitmap_byte    (),
        .colors_address (10'd0),
        .colors_byte    ()
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // In the chip the memories start at zero; in the simulator they start
    // unknown. The test bench does what the chip does.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // The picture the test bench expects: 8,000 bytes, drawn here.
    reg [7:0] expected [0:7999];
    integer   pixels_expected = 0;

    // Light one pixel of the expected picture.
    task light;
        input integer x;
        input integer y;
        begin
            if (expected[y * 40 + x / 8][7 - x % 8] == 0) pixels_expected = pixels_expected + 1;
            expected[y * 40 + x / 8][7 - x % 8] = 1;
        end
    endtask

    // A straight line from (x0, y0) to (x1, y1): Bresenham's algorithm as
    // Alois Zingl gives it, with ordinary integers.
    task draw_line;
        input integer x0;
        input integer y0;
        input integer x1;
        input integer y1;
        integer dx, dy, sx, sy, error, e2;
        begin
            dx = (x1 > x0) ? x1 - x0 : x0 - x1;
            sx = (x0 < x1) ? 1 : -1;
            dy = (y1 > y0) ? y0 - y1 : y1 - y0;     // minus the distance
            sy = (y0 < y1) ? 1 : -1;
            error = dx + dy;
            light(x0, y0);
            while (x0 != x1 || y0 != y1) begin
                e2 = 2 * error;
                if (e2 >= dy) begin error = error + dy; x0 = x0 + sx; end
                if (e2 <= dx) begin error = error + dx; y0 = y0 + sy; end
                light(x0, y0);
            end
        end
    endtask

    // The 32 steps of draw.s, as its comments describe them.
    integer k;
    initial begin
        for (n = 0; n < 8000; n = n + 1) expected[n] = 8'h00;
        for (k = 0; k < 32; k = k + 1) begin
            draw_line(10 * k,       0,   0,   199 - 6 * k);
            draw_line(10 * k,       199, 0,   6 * k);
            draw_line(319 - 10 * k, 199, 319, 6 * k);
            draw_line(319 - 10 * k, 0,   319, 199 - 6 * k);
        end
    end

    localparam LIMIT = 8_000_000;

    integer cycle         = 0;
    integer step_began    = 0;  // the cycle at which the LEDs were last written
    integer bitmap_writes = 0;  // writes into the bitmap since then
    integer colors_writes = 0;  // writes into the colors since then
    integer zero_writes   = 0;  // writes into page zero
    integer stack_writes  = 0;  // writes onto the stack
    integer stray_writes  = 0;  // writes anywhere else: there should be none
    integer nmis          = 0;
    integer errors        = 0;
    integer different;
    reg [15:0] where;           // the address of a byte that differs
    integer lit;
    integer colors_wrong;
    reg     drawn         = 0;  // the LEDs show 33: the lines are drawn
    reg     painted       = 0;  // and the new colors are in every cell
    integer drawn_at      = 0;
    integer painted_at    = 0;

    // At the end of every cycle: what did the processor do?
    always @(negedge clk) begin
        if (step & ~reset) begin
            cycle = cycle + 1;
            if (address == 16'hFFFA && !write) nmis = nmis + 1;   // the NMI vector is read
            if (write) begin
                if (address == 16'h8000) begin
                    $display("cycle %8d: %2d on the LEDs; since the write before, %7d cycles, %5d writes into the bitmap, %4d into the colors",
                             cycle, data_out, cycle - step_began, bitmap_writes, colors_writes);
                    step_began    = cycle;
                    bitmap_writes = 0;
                    colors_writes = 0;
                    if (data_out == 33 && !drawn) begin
                        drawn    = 1;
                        drawn_at = cycle;
                    end
                end else if (address >= 16'hA000 && address <= 16'hBFFF) begin
                    bitmap_writes = bitmap_writes + 1;
                end else if (address >= 16'h9C00 && address <= 16'h9FFF) begin
                    colors_writes = colors_writes + 1;
                    // S2, pressed at the first write into the colors: the
                    // program has just set FAST to 0 for this round.
                    if (cycle < 100 && !s2 && !s2_pressed) begin
                        s2 = 1;
                        s2_pressed = 1;
                        pressed_at = cycle;
                        $display("cycle %8d: S2 is pressed", cycle);
                    end
                    if (drawn && colors_writes == 1024 && !painted) begin
                        painted    = 1;
                        painted_at = cycle;
                    end
                end else if (address <= 16'h00FF) begin
                    zero_writes = zero_writes + 1;
                end else if (address >= 16'h0100 && address <= 16'h01FF) begin
                    stack_writes = stack_writes + 1;
                end else begin
                    stray_writes = stray_writes + 1;
                    $display("cycle %8d: a write at %h, where the program should not write", cycle, address);
                end
            end
            if (s2 && cycle > pressed_at + 20) s2 = 0;     // S2 let go, twenty cycles later
        end
    end

    initial begin
        wait (drawn || cycle >= LIMIT);
        @(negedge clk);
        if (!drawn) begin
            $display("FAIL: computer, the LEDs never showed 33 in %0d cycles, pc = %h", cycle, dut.processor.pc);
            $fatal;
        end
        // The lines are drawn: compare the bitmap with the expected picture.
        different = 0;
        lit = 0;
        for (n = 0; n < 8000; n = n + 1) begin
            if (dut.the_bitmap.cells[n] !== expected[n]) begin
                different = different + 1;
                where = 16'hA000 + n;
                if (different <= 10) $display("wrong: the byte at %h is %h, expected %h (line %0d, pixels %0d to %0d)",
                                              where, dut.the_bitmap.cells[n], expected[n],
                                              n / 40, (n % 40) * 8, (n % 40) * 8 + 7);
            end
            for (k = 0; k < 8; k = k + 1) lit = lit + dut.the_bitmap.cells[n][k];
        end
        // The 192 bytes after the picture are cleared too, and never drawn on.
        for (n = 8000; n < 8192; n = n + 1) begin
            if (dut.the_bitmap.cells[n] !== 8'h00) different = different + 1;
        end
        colors_wrong = 0;
        for (n = 0; n < 1024; n = n + 1) begin
            if (dut.the_colors.cells[n] !== 8'hE6) colors_wrong = colors_wrong + 1;
        end
        $display("cycle %8d: the lines are drawn: %0d pixels lit, %0d expected; %0d bytes of the bitmap differ from the expected picture; %0d cells not light blue on blue",
                 cycle, lit, pixels_expected, different, colors_wrong);
        if (different != 0 || colors_wrong != 0 || lit != pixels_expected) errors = errors + 1;

        // Then the first new colors.
        wait (painted || cycle >= drawn_at + 20_000);
        @(negedge clk);
        colors_wrong = 0;
        for (n = 0; n < 1024; n = n + 1) begin
            if (dut.the_colors.cells[n] !== 8'h10) colors_wrong = colors_wrong + 1;
        end
        $display("cycle %8d: the 1,024 bytes of colors rewritten, %0d cycles after 33 on the LEDs: %0d cells not white on black",
                 cycle, painted_at - drawn_at, colors_wrong);
        if (!painted || colors_wrong != 0) errors = errors + 1;
        $display("writes: %0d into page zero, %0d onto the stack, %0d anywhere else; %0d NMI", zero_writes, stack_writes,
                 stray_writes, nmis);
        if (stray_writes != 0 || nmis < 1) errors = errors + 1;

        if (errors == 0) begin
            $display("PASS: computer, the 128 lines of draw.s are the expected picture, %0d pixels, drawn by cycle %0d; then the colors change",
                     lit, drawn_at);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;
        end
    end
endmodule
