// Chapter 21, test bench for the whole computer, with the program of the
// board, keys.s, a keyboard and its module: ch9350.v, which sends frames on
// the wire keyboard as the CH9350 does while someone types. The Mac only
// listens, on tx: the program sends it what it writes on the screen.
//
// From the reports that ch9350.v sent, the test bench works out the lines
// keys.s should write: one for each report that differs from the one before,
// the first compared with a report of zeros; and, before a report, a line
// "Bytes skipped:" when bytes that begin no frame came before it. It keeps a screen of its own, as
// in chapter 18, where it writes the same characters with the same rules as
// the console. When the module has sent everything and the processor has
// taken every byte, it reads the screen cell by cell, as an eye would, and
// compares it with its own; it compares what the Mac heard with the text it
// expects; and it checks the LEDs, the bytes that keys.s skipped, and how
// full the queue got.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire        tx;
    wire        keyboard;
    reg         go    = 0;      // the module may begin
    wire        done;
    wire [3:0]  phase;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk            (clk),
        .reset          (1'b0),
        .step           (step),
        .irq            (1'b0),     // nothing asks for IRQ
        .nmi            (1'b0),
        .leds           (leds),
        .address        (address),
        .data_in        (data_in),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (13'd0),    // no display in this test bench
        .bitmap_byte    (),
        .colors_address (10'd0),
        .colors_byte    (),
        .rx             (1'b1),     // the Mac sends nothing
        .tx             (tx),
        .keyboard       (keyboard)
    );

    ch9350 module_and_keyboard (
        .go    (go),
        .tx    (keyboard),
        .done  (done),
        .phase (phase)
    );

    // One tick every 40 ns, as for the pixel clock.
    always #20 clk = ~clk;

    // In the chip the memories start at zero; in the simulator they start
    // unknown. The test bench does what the chip does.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // The Mac listens: a falling edge is a start bit, then the middle of each
    // bit. Our transmitter's bits last 219 ticks: 8,760 ns.
    localparam BIT = 8760;
    reg [7:0] heard [0:8191];
    integer   count  = 0;
    integer   broken = 0;           // bytes heard without their stop bit
    reg [7:0] byte_heard;
    integer   k;
    initial begin
        forever begin
            @(negedge tx);
            #(BIT / 2);
            if (tx == 0) begin
                for (k = 0; k < 8; k = k + 1) begin
                    #(BIT);
                    byte_heard[k] = tx;
                end
                #(BIT);
                if (tx !== 1) broken = broken + 1;
                heard[count] = byte_heard;
                count = count + 1;
            end
        end
    end

    // The font begins the ROM: the letter for the code C is at cell 8 x (C - 32).
    function [7:0] font;
        input integer code;
        input integer line;
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction

    // The test bench's screen, as in chapter 18: a code for each cell. And
    // the text the Mac should hear: the same characters.
    reg [7:0] screen [0:999];
    integer   col = 0;
    integer   row = 0;
    reg [7:0] text [0:8191];
    integer   length = 0;

    task down;
        integer j;
        begin
            if (row < 24) begin
                row = row + 1;
            end else begin
                for (j = 0; j < 960; j = j + 1) screen[j] = screen[j + 40];
                for (j = 960; j < 1000; j = j + 1) screen[j] = 32;
            end
        end
    endtask

    task put;
        input integer code;
        begin
            text[length] = code;
            length = length + 1;
            if (code == 13) begin
                col = 0;
            end else if (code == 10) begin
                down;
            end else if (code >= 32 && code <= 126) begin
                screen[row * 40 + col] = code;
                col = col + 1;
                if (col == 40) begin
                    col = 0;
                    down;
                end
            end
        end
    endtask

    // Some text: Verilog keeps a string at the right of its register, with
    // zeros on the left, which are skipped.
    task put_text;
        input [8 * 40 - 1:0] words;
        integer j;
        begin
            for (j = 39; j >= 0; j = j - 1) begin
                if (words[8 * j +: 8] != 0) put(words[8 * j +: 8]);
            end
        end
    endtask

    // A digit, 0 to 15, in hexadecimal.
    task put_digit;
        input [3:0] value;
        begin
            if (value < 10) put("0" + value);
            else put("A" + value - 10);
        end
    endtask

    // A line of keys.s: the eight bytes of a report, the first on the left.
    task put_report;
        input [63:0] report;
        integer j;
        begin
            for (j = 7; j >= 0; j = j - 1) begin
                put_digit(report[8 * j + 4 +: 4]);
                put_digit(report[8 * j +: 4]);
                if (j != 0) put(" ");
            end
            put(13);
            put(10);
        end
    endtask

    // keys.s's line about the bytes it skipped: so many so far, in hexadecimal.
    task put_skipped;
        input [7:0] count;
        begin
            put_text("Bytes skipped: ");
            put_digit(count[7:4]);
            put_digit(count[3:0]);
            put(13);
            put(10);
        end
    endtask

    // What keys.s writes first.
    initial begin
        for (n = 0; n < 1000; n = n + 1) screen[n] = 32;
        put_text("Our Own 6502, Gate by Gate");
        put(13);
        put(10);
        put_text("Chapter 21: A Real USB Keyboard");
        put(13);
        put(10);
        put(13);
        put(10);
        put_text("Keyboard reports, when they change:");
        put(13);
        put(10);
    end

    // Read the bitmap cell by cell: each cell must hold the letter of the
    // test bench's screen. Write what is there: a ? if no letter of the font.
    integer wrong_cells;
    task read_screen;
        integer r, c, line, code, found;
        reg     same;
        begin
            wrong_cells = 0;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c = 0; c < 40; c = c + 1) begin
                    same = 1;
                    for (line = 0; line < 8; line = line + 1) begin
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(screen[r * 40 + c], line)) same = 0;
                    end
                    if (!same) wrong_cells = wrong_cells + 1;
                    found = 0;
                    for (code = 32; code < 127 && found == 0; code = code + 1) begin
                        same = 1;
                        for (line = 0; line < 8; line = line + 1) begin
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(code, line)) same = 0;
                        end
                        if (same) found = code;
                    end
                    $write("%c", found ? found : "?");
                end
                $display("|");
            end
        end
    endtask

    localparam LIMIT = 8_000_000;

    integer cycle         = 0;
    integer listening_at  = 0;      // when keys.s first looked at the queue
    integer drained_at    = 0;
    integer polls         = 0;      // reads of $8021 in a row, with nothing taken between
    integer taken         = 0;      // bytes the processor took from the queue
    integer most          = 0;      // the most bytes that waited in the queue at once
    integer most_at       = 0;
    integer stray_writes  = 0;      // writes where nothing should be written
    reg [7:0] led_bytes [0:255];    // what keys.s wrote at $8000, in order
    integer led_writes    = 0;
    integer errors        = 0;
    integer waiting_now;
    reg     finished      = 0;

    always @(posedge clk) begin
        waiting_now = (dut.keyboard_queue.in - dut.keyboard_queue.out) & 255;
        if (waiting_now > most) begin
            most    = waiting_now;
            most_at = cycle;
        end
        if (step && !finished) begin
            cycle = cycle + 1;
            if (write) begin
                if (address == 16'h8000) begin
                    led_bytes[led_writes] = data_out;
                    led_writes = led_writes + 1;
                end
                if (!(address < 16'h0200 || address == 16'h8000 || address == 16'h8010 ||
                      address[15:10] == 6'b100111 || address[15:13] == 3'b101))
                    stray_writes = stray_writes + 1;
            end else begin
                if (address == 16'h8020) begin
                    taken = taken + 1;
                    polls = 0;
                end
                if (address == 16'h8021) polls = polls + 1;
            end

            // keys.s looks at the queue for the first time: it is listening.
            // Read the screen, and let the module begin.
            if (!go && address == 16'h8021 && !write) begin
                listening_at = cycle;
                $display("cycle %7d: keys.s listens; the screen:", cycle);
                read_screen;
                $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
                if (wrong_cells != 0) errors = errors + 1;
                go = 1;
            end

            // Everything sent, everything taken, and keys.s waiting again for
            // a long while: it has written all it had to write.
            if (done && !dut.queued && polls > 2000 && drained_at == 0) begin
                drained_at = cycle;
                finished   = 1;
            end
        end
    end

    integer    lines;
    integer    said;
    integer    j, wrong_text, wrong_leds;
    reg [63:0] last;
    initial begin
        wait (finished);
        @(negedge clk);

        // The lines keys.s should have written, from the reports that were
        // sent; and the LEDs: 0 at the start, then the first byte of each line.
        last  = 64'h0;
        lines = 0;
        said  = 0;
        wrong_leds = (led_bytes[0] !== 8'h00);
        for (j = 0; j < module_and_keyboard.reports; j = j + 1) begin
            if (module_and_keyboard.skipped[j] != said) begin
                said = module_and_keyboard.skipped[j];
                put_skipped(said);
            end
            if (module_and_keyboard.sent[j] !== last) begin
                last = module_and_keyboard.sent[j];
                put_report(last);
                lines = lines + 1;
                if (led_bytes[lines] !== last[63:56]) wrong_leds = wrong_leds + 1;
            end
        end
        $display("cycle %7d: the module has sent %0d bytes, %0d frames, %0d of them reports of the keyboard, %0d different from the one before; the screen:",
                 drained_at, module_and_keyboard.bytes, module_and_keyboard.frames, module_and_keyboard.reports, lines);
        read_screen;
        $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
        if (wrong_cells != 0) errors = errors + 1;

        wrong_text = 0;
        for (j = 0; j < length; j = j + 1) begin
            if (j >= count || heard[j] !== text[j]) wrong_text = wrong_text + 1;
        end
        $display("the Mac heard %0d bytes, %0d expected, %0d different, %0d without their stop bit",
                 count, length, wrong_text, broken);
        if (count != length || wrong_text != 0 || broken != 0) errors = errors + 1;

        $display("the processor took %0d bytes from the queue; keys.s skipped %0d (SKIPPED), and the module sent %0d that begin no frame",
                 taken, dut.the_ram.cells[16'h00E8], module_and_keyboard.junk);
        if (taken != module_and_keyboard.bytes || dut.the_ram.cells[16'h00E8] != module_and_keyboard.junk) errors = errors + 1;

        $display("the LEDs were written %0d times, %0d with the wrong byte; they show %b at the end",
                 led_writes, wrong_leds, leds);
        if (led_writes != lines + 1 || wrong_leds != 0 || leds !== 6'b000000) errors = errors + 1;

        $display("the queue held at most %0d bytes at once (cycle %0d), of 255", most, most_at);
        $display("keys.s listened at cycle %0d; %0d writes where nothing should be written", listening_at, stray_writes);
        if (stray_writes != 0) errors = errors + 1;

        if (errors == 0)
            $display("PASS: computer, keys.s wrote the %0d reports that changed, and what it skipped, on the screen and to the Mac, by cycle %0d",
                     lines, drained_at);
        else
            $display("FAIL: computer, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        wait (cycle == LIMIT);
        $display("FAIL: computer, not finished after %0d cycles (the module is at phase %0d, %0d bytes taken)",
                 LIMIT, phase, taken);
        $finish;
    end
endmodule
