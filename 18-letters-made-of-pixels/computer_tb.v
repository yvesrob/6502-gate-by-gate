// Chapter 18, test bench for the whole computer, with the program of the
// board, type.s. The test bench presses S2 at the start, as you could on the
// board, so that the program does not wait between letters and lines: the
// text and the 48 lines of stripes then take a few million cycles instead of
// twenty seconds. It watches every write, and writes a line each time the
// LEDs count one more.
//
// It keeps a screen of its own: 25 rows of 40 codes, where it types the same
// text, the same 95 letters and the same stripes, with the same rules as the
// console, but with plain integers. Twice, it reads the bitmap cell by cell,
// as an eye would: just before the first scroll, and after the last line.
// Each cell must hold the eight bytes that the font, in the ROM from $C000,
// gives for the code of the test bench's screen. It also writes what it
// reads, as text, so that we can read the screen in this output.
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

    // The font is the first thing in the ROM: the letter for the code C
    // begins at $C000 + 8 x (C - 32), that is at cell 8 x (C - 32) of the ROM.
    function [7:0] font;
        input integer code;
        input integer line;
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction

    // The test bench's screen: a code for each cell, 32 (a space) when empty.
    reg [7:0] screen [0:999];
    integer   col = 0;
    integer   row = 0;

    // The next row; after the last, everything moves up one row.
    task down;
        integer k;
        begin
            if (row < 24) begin
                row = row + 1;
            end else begin
                for (k = 0; k < 960; k = k + 1) screen[k] = screen[k + 40];
                for (k = 960; k < 1000; k = k + 1) screen[k] = 32;
            end
        end
    endtask

    // A code, as the console takes it.
    task put;
        input integer code;
        begin
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

    // A line of text, then 13 and 10. Verilog keeps a string at the right of
    // its register, with zeros on the left: those are skipped.
    task put_line;
        input [8 * 40 - 1:0] text;
        integer k;
        begin
            for (k = 39; k >= 0; k = k - 1) begin
                if (text[8 * k +: 8] != 0) put(text[8 * k +: 8]);
            end
            put(13);
            put(10);
        end
    endtask

    // The 40 letters of a line of stripes: letter number s of the font first.
    task put_stripe;
        input integer s;
        integer k;
        begin
            for (k = 0; k < 40; k = k + 1) put(32 + s + k);
        end
    endtask

    // The two screens the test bench expects: before the first scroll, when
    // the LEDs show 22, and after the last line, when they show 56.
    reg [7:0] before_scroll [0:999];
    reg [7:0] at_the_end    [0:999];
    integer s;
    initial begin
        for (n = 0; n < 1000; n = n + 1) screen[n] = 32;
        put_line("Our Own 6502, Gate by Gate");
        put_line("Chapter 18: Letters Made of Pixels");
        put(13);
        put(10);
        put_line("Each letter you see is eight bytes of");
        put_line("the ROM, copied into the picture by");
        put_line("our 6502, one line of pixels at a time.");
        put_line("Here are the 95 characters it knows:");
        for (n = 32; n < 127; n = n + 1) put(n);
        put(13);
        put(10);
        for (s = 0; s < 48; s = s + 1) begin
            if (s == 14) for (n = 0; n < 1000; n = n + 1) before_scroll[n] = screen[n];
            put_stripe(s);
        end
        for (n = 0; n < 1000; n = n + 1) at_the_end[n] = screen[n];
    end

    // Read the bitmap cell by cell. Each cell must hold the letter of the
    // expected code; the test bench also looks for the letter that is there,
    // among the 95 of the font, and writes it: a ? if it is none of them.
    integer wrong_cells;
    task read_screen;
        input integer which;    // 0: before the first scroll, 1: at the end
        integer r, c, line, code, found;
        reg [7:0] expected_code;
        reg       same;
        begin
            wrong_cells = 0;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c = 0; c < 40; c = c + 1) begin
                    expected_code = which ? at_the_end[r * 40 + c] : before_scroll[r * 40 + c];
                    same = 1;
                    for (line = 0; line < 8; line = line + 1) begin
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(expected_code, line)) same = 0;
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

    localparam LIMIT = 9_000_000;

    integer cycle         = 0;
    integer line_began    = 0;  // the cycle at which the LEDs were last written
    integer bitmap_writes = 0;  // writes into the bitmap since then
    integer colors_writes = 0;  // writes into the colors since then
    integer zero_writes   = 0;  // writes into page zero
    integer stack_writes  = 0;  // writes onto the stack
    integer stray_writes  = 0;  // writes anywhere else: there should be none
    integer nmis          = 0;
    integer errors        = 0;
    integer scroll_began  = 0;  // the first scroll: its first write, at $A000...
    integer scroll_ended  = 0;  // ...and its last, at $BFFF
    integer scroll_writes = 0;
    reg     at_22         = 0;  // the LEDs show 22: the next line is the first to scroll
    reg     done          = 0;  // the LEDs show 56: the 48 lines of stripes are written

    // At the end of every cycle: what did the processor do?
    always @(negedge clk) begin
        if (step & ~reset) begin
            cycle = cycle + 1;
            if (address == 16'hFFFA && !write) nmis = nmis + 1;   // the NMI vector is read
            if (write) begin
                if (address == 16'h8000) begin
                    $display("cycle %7d: %2d on the LEDs; since the write before, %6d cycles, %4d writes into the bitmap, %4d into the colors",
                             cycle, data_out, cycle - line_began, bitmap_writes, colors_writes);
                    line_began    = cycle;
                    bitmap_writes = 0;
                    colors_writes = 0;
                    if (data_out == 22) at_22 = 1;
                    if (data_out == 56) done = 1;
                end else if (address >= 16'hA000 && address <= 16'hBFFF) begin
                    bitmap_writes = bitmap_writes + 1;
                    if (leds >= 9 && address == 16'hA000 && scroll_began == 0) scroll_began = cycle;
                    if (scroll_began != 0 && scroll_ended == 0) begin
                        scroll_writes = scroll_writes + 1;
                        if (address == 16'hBFFF) scroll_ended = cycle;
                    end
                end else if (address >= 16'h9C00 && address <= 16'h9FFF) begin
                    colors_writes = colors_writes + 1;
                    // S2, pressed at the first write into the colors: the
                    // program has just set FAST to 0 for this round.
                    if (cycle < 100 && !s2 && !s2_pressed) begin
                        s2 = 1;
                        s2_pressed = 1;
                        pressed_at = cycle;
                        $display("cycle %7d: S2 is pressed", cycle);
                    end
                end else if (address <= 16'h00FF) begin
                    zero_writes = zero_writes + 1;
                end else if (address >= 16'h0100 && address <= 16'h01FF) begin
                    stack_writes = stack_writes + 1;
                end else begin
                    stray_writes = stray_writes + 1;
                    if (stray_writes <= 10) $display("cycle %7d: a write at %h, where the program should not write", cycle, address);
                end
            end
            if (s2 && cycle > pressed_at + 20) s2 = 0;     // S2 let go, twenty cycles later
        end
    end

    // The colors, and the 192 bytes after the picture, which no letter touches.
    integer colors_wrong;
    integer hidden_wrong;
    task check_the_rest;
        begin
            colors_wrong = 0;
            for (n = 0; n < 1024; n = n + 1) if (dut.the_colors.cells[n] !== 8'hE6) colors_wrong = colors_wrong + 1;
            hidden_wrong = 0;
            for (n = 8000; n < 8192; n = n + 1) if (dut.the_bitmap.cells[n] !== 8'h00) hidden_wrong = hidden_wrong + 1;
            $display("%0d cells of 1,000 differ from the expected screen; %0d cells of the colors not light blue on blue; %0d of the 192 bytes after the picture not 0",
                     wrong_cells, colors_wrong, hidden_wrong);
            if (wrong_cells != 0 || colors_wrong != 0 || hidden_wrong != 0) errors = errors + 1;
        end
    endtask

    initial begin
        wait (at_22 || cycle >= LIMIT);
        @(negedge clk);
        if (!at_22) begin
            $display("FAIL: computer, the LEDs never showed 22 in %0d cycles, pc = %h", cycle, dut.processor.pc);
            $fatal;
        end
        $display("cycle %7d: the screen, read cell by cell, before the first scroll:", cycle);
        read_screen(0);
        check_the_rest;

        wait (done || cycle >= LIMIT);
        @(negedge clk);
        if (!done) begin
            $display("FAIL: computer, the LEDs never showed 56 in %0d cycles, pc = %h", cycle, dut.processor.pc);
            $fatal;
        end
        $display("cycle %7d: the screen, read cell by cell, after the last line:", cycle);
        read_screen(1);
        check_the_rest;

        if (scroll_ended != 0) $display("the first scroll: %0d writes into the bitmap, from cycle %0d ($A000) to cycle %0d ($BFFF): %0d cycles",
                                        scroll_writes, scroll_began, scroll_ended, scroll_ended - scroll_began + 1);
        $display("writes: %0d into page zero, %0d onto the stack, %0d anywhere else; %0d NMI", zero_writes, stack_writes,
                 stray_writes, nmis);
        if (stray_writes != 0 || nmis < 1) errors = errors + 1;

        if (errors == 0) begin
            $display("PASS: computer, the screen reads as expected before the first scroll and after the 48 lines of stripes, by cycle %0d",
                     cycle);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;
        end
    end
endmodule
