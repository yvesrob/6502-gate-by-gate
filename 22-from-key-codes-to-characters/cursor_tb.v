// Chapter 22, test bench for the cursor (typing.s and console.s): the whole
// computer, with the monitor in the ROM, a keyboard and a Mac, as in
// computer_tb; but the person who types stops to think now and then, longer
// than a quarter of a second: ch9350.v tells its story with PAUSES. When it
// is done, and the cursor shows, the test bench presses S1, the reset; then
// the Mac types readback.txt.
//
// The test bench watches the bitmap as an eye would. Each byte the processor
// writes there is compared with the byte that was there: the cursor turns a
// cell over, its eight lines one after the other, each byte becoming its
// opposite. Eight such writes in a row, lines 0 to 7 of one cell, are a turn:
// the cell shows turned over, or it is back as it was. The test bench checks:
//   - the turns, in order, against a list written by hand from the story:
//     which cell, whether it shows or hides, and when: a quarter of a second
//     after the last thing that happened (3,150,000 cycles, within 2 %: the
//     wait does not count its turns while it reads a frame from the module,
//     and the module sends some while a key, even Shift, is held down), or
//     right after a key went down or the Mac sent a byte (within 20,000
//     cycles, the time a report of the keyboard takes to arrive);
//   - each turn is at the cell where the next letter will go, as the test
//     bench's own screen says from what the Mac heard;
//   - nothing else is written on the screen while a cell shows turned over;
//   - no cell shows turned over while a key is held down;
//   - what the Mac heard, byte for byte, against the conversation written by
//     hand: the cursor sends nothing;
//   - at the end, the whole screen, cell by cell: once while the cursor shows
//     (each cell as expected, the cursor's turned over), once after it hid
//     (each cell as expected).
// It writes what the Mac heard into heard-cursor.txt, and the turns into
// turns.txt, for the judge in Python.
`timescale 1ns/1ns
module cursor_tb;
    reg         clk   = 0;
    reg         s1    = 0;      // button S1, the reset
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire        rx;
    wire        tx;
    wire        keyboard;
    reg         typing = 0;     // the person may begin to type
    wire        typed_all;
    wire [3:0]  phase;
    reg         go     = 0;     // the Mac may begin
    wire        done;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk            (clk),
        .reset          (s1),
        .step           (step),
        .irq            (1'b0),     // nothing asks for IRQ
        .nmi            (1'b0),     // nobody presses S2
        .leds           (leds),
        .address        (address),
        .data_in        (data_in),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (13'd0),    // no display in this test bench
        .bitmap_byte    (),
        .colors_address (10'd0),
        .colors_byte    (),
        .rx             (rx),
        .tx             (tx),
        .keyboard       (keyboard)
    );

    ch9350 #(.PAUSES(1), .WIRE("wire-cursor.txt")) module_and_keyboard (
        .go    (typing),
        .tx    (keyboard),
        .done  (typed_all),
        .phase (phase)
    );

    mac #(.FILE("readback.txt")) the_mac (
        .go   (go),
        .tx   (tx),
        .rx   (rx),
        .done (done)
    );

    // One tick every 40 ns: a cycle of the processor every two, 12.6 million
    // a second.
    always #20 clk = ~clk;

    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // The conversation the Mac must hear, written by hand.
    reg [7:0] expected [0:1023];
    integer   expected_length = 0;
    task say(input [8 * 48 - 1:0] what);    // some text, its first zero bytes left out
        integer k;
        reg     begun;
        begin
            begun = 0;
            for (k = 47; k >= 0; k = k - 1) begin
                if (what[8 * k +: 8] != 0) begun = 1;
                if (begun) begin
                    expected[expected_length] = what[8 * k +: 8];
                    expected_length = expected_length + 1;
                end
            end
        end
    endtask
    task say_line(input [8 * 48 - 1:0] what);
        begin
            say(what);
            say({8'd13, 8'd10});
        end
    endtask
    initial begin
        say_line("Our Own 6502, Gate by Gate");
        say_line("Chapter 22: From Key Codes to Characters");
        say("*"); say("C"); say({8'd8, " ", 8'd8});        // c, then Backspace
        say_line("8000"); say_line("8000: 00");
        say("*"); say("00"); say_line("\\");                // the 0 held down, then Escape
        say("*");
        say_line("Our Own 6502, Gate by Gate");             // S1
        say_line("Chapter 22: From Key Codes to Characters");
        say("*"); say_line("\\");                           // the Mac: Escape, then its lines
        say("*"); say_line("0400.0401"); say_line("0400: 00 00");
        say("*"); say_line("0500"); say_line("0500: 00");
        say("*"); say_line("8000"); say_line("8000: 00");
        say("*");
    end

    // The turns the eye must see, written by hand from the story: show (1) or
    // hide (0), the row and the column of the cell, and when: QUARTER, a
    // quarter of a second after the last thing that happened; KEY, right
    // after a key went down or the Mac sent a byte.
    localparam QUARTER = 0, KEY = 1;
    integer want_kind [0:31];
    integer want_row  [0:31];
    integer want_col  [0:31];
    integer want_when [0:31];
    integer wanted = 0;
    task want(input integer kind, input integer r, input integer c, input integer when);
        begin
            want_kind[wanted] = kind;
            want_row[wanted]  = r;
            want_col[wanted]  = c;
            want_when[wanted] = when;
            wanted = wanted + 1;
        end
    endtask
    initial begin
        want(1, 3, 1, QUARTER);     // the first prompt: nobody types
        want(0, 3, 1, QUARTER);     // the Shift held down: it blinks on
        want(1, 3, 1, QUARTER);
        want(0, 3, 1, KEY);         // c: hidden before the C is written
        want(1, 3, 2, QUARTER);     // after the C
        want(0, 3, 2, KEY);         // Backspace
        want(1, 3, 1, QUARTER);     // back where the C was
        want(0, 3, 1, KEY);         // the 8 of 8000
        want(1, 3, 5, QUARTER);     // after 8000
        want(0, 3, 5, KEY);         // Return
                                    // the 0 held down: no turn
        want(1, 5, 3, QUARTER);     // after 00, a quarter of a second after the 0 came up
        want(0, 5, 3, KEY);         // Escape
        want(1, 6, 1, QUARTER);     // the next prompt; S1 while it shows
        want(1, 3, 1, QUARTER);     // after S1, the title and the prompt
        want(0, 3, 1, KEY);         // the Mac's Escape
                                    // the Mac's three lines: no turn
        want(1, 10, 1, QUARTER);    // the last prompt
        want(0, 10, 1, QUARTER);
    end

    // The font begins the ROM: the letter for the code C is at cell 8 x (C - 32).
    function [7:0] font;
        input integer code;
        input integer line;
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction

    // The test bench's screen, as in computer_tb: a code for each cell, from
    // what the Mac heard since the last reset.
    reg [7:0] screen [0:999];
    integer   col = 0;
    integer   row = 0;
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
    task put;
        input integer code;
        begin
            if (code == 13) begin
                col = 0;
            end else if (code == 10) begin
                down;
            end else if (code == 8) begin
                if (col > 0) begin
                    col = col - 1;
                end else if (row > 0) begin
                    row = row - 1;
                    col = 39;
                end
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
    integer heard_from = 0;     // where, in what the Mac heard, the last reset began
    task replay;
        integer k;
        begin
            for (k = 0; k < 1000; k = k + 1) screen[k] = 32;
            col = 0;
            row = 0;
            for (k = heard_from; k < the_mac.count; k = k + 1) put(the_mac.heard[k]);
        end
    endtask

    // Read the bitmap cell by cell: each cell must hold the letter of the test
    // bench's screen; the cell turned, if there is one, its letter turned over.
    integer wrong_cells;
    task read_screen(input integer turned_cell);
        integer r, c, line, code, found;
        reg     same, over;
        begin
            wrong_cells = 0;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c = 0; c < 40; c = c + 1) begin
                    same = 1;
                    for (line = 0; line < 8; line = line + 1)
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !==
                            (r * 40 + c == turned_cell ? ~font(screen[r * 40 + c], line) : font(screen[r * 40 + c], line))) same = 0;
                    if (!same) wrong_cells = wrong_cells + 1;
                    found = 0;
                    over = 0;
                    for (code = 32; code < 127 && found == 0; code = code + 1) begin
                        same = 1;
                        for (line = 0; line < 8; line = line + 1)
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(code, line)) same = 0;
                        if (same) found = code;
                        same = 1;
                        for (line = 0; line < 8; line = line + 1)
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== ~font(code, line)) same = 0;
                        if (same) begin
                            found = code;
                            over = 1;
                        end
                    end
                    // what is there: a letter; # an empty cell turned over, % a letter turned over
                    $write("%c", found == 0 ? "?" : over ? (found == 32 ? "#" : "%") : found);
                end
                $display("|");
            end
        end
    endtask

    localparam LIMIT = 60_000_000;
    localparam QUARTER_CYCLES = 3_150_000;      // a quarter of a second at 12.6 MHz
    localparam WITHIN         = 63_000;         // 2 %

    integer cycle  = 0;
    integer errors = 0;

    // What happens, for the timing of the turns: a key goes down or comes up
    // (the module's count of keys held down changes), the Mac sends a byte
    // (its start bit: a fall of rx when no byte is under way), the Mac hears
    // a byte, S1 is let go.
    integer last_event   = 0;
    integer last_turn    = 0;
    integer held_before  = 0;
    integer count_before = 0;
    reg     rx_before    = 1;
    integer rx_busy      = 0;       // until this cycle, a byte from the Mac is under way
    always @(posedge clk) begin
        if (step) cycle = cycle + 1;
        if (module_and_keyboard.held != held_before) begin
            held_before = module_and_keyboard.held;
            last_event = cycle;
        end
        if (rx_before && !rx && cycle >= rx_busy) begin
            last_event = cycle;
            rx_busy = cycle + 1_100;    // ten bits of 8,746 ns: 1,094 cycles
        end
        rx_before = rx;
        if (the_mac.count != count_before) begin
            count_before = the_mac.count;
            last_event = cycle;
        end
    end

    // The eye.
    reg [7:0] seen [0:8191];        // the bitmap as the eye last saw it
    initial for (n = 0; n < 8192; n = n + 1) seen[n] = 8'h00;
    integer turned       = -1;      // the cell that shows turned over; -1: none
    integer lines_turned = 0;       // lines of a turn seen so far, one after the other
    integer turning_cell = -1;
    integer written_while_shown = 0;
    integer shown_while_held    = 0;
    integer offset, a_cell, a_line;
    integer turns = 0;
    integer turn_at    [0:63];
    integer turn_kind  [0:63];
    integer turn_cell  [0:63];
    integer turn_since [0:63];
    integer turn_heard [0:63];
    integer turn_place [0:63];      // where the next letter goes, as the test bench's screen says
    integer since;

    task a_turn(input integer c);
        begin
            replay;
            since = cycle - (last_event > last_turn ? last_event : last_turn);
            if (turns < 64) begin
                turn_at[turns]    = cycle;
                turn_cell[turns]  = c;
                turn_since[turns] = since;
                turn_heard[turns] = the_mac.count;
                turn_place[turns] = row * 40 + col;
                if (turned < 0) begin
                    turn_kind[turns] = 1;
                    turned = c;
                    if (module_and_keyboard.held != 0) shown_while_held = shown_while_held + 1;
                end else if (turned == c) begin
                    turn_kind[turns] = 0;
                    turned = -1;
                end else begin
                    turn_kind[turns] = 2;       // another cell turned while one shows
                end
                $display("cycle %8d: the cell at row %0d, column %0d %0s, %0d cycles after the last thing that happened (%0.4f s)",
                         cycle, c / 40, c % 40, turn_kind[turns] == 1 ? "shows turned over" :
                         turn_kind[turns] == 0 ? "is back as it was" : "turns over WHILE ANOTHER SHOWS", since, since / 12.6e6);
            end
            turns = turns + 1;
            last_turn = cycle;
        end
    endtask

    always @(posedge clk) begin
        if (step && write && address >= 16'h9C00 && address <= 16'hBFFF) begin
            if (address >= 16'hA000) begin
                offset = address - 16'hA000;
                a_cell = (offset < 8000) ? (offset / 320) * 40 + offset % 40 : -1;
                a_line = (offset % 320) / 40;
                if (a_cell >= 0 && data_out == ~seen[offset] && a_line == lines_turned &&
                    (lines_turned == 0 || a_cell == turning_cell)) begin
                    turning_cell = a_cell;
                    lines_turned = lines_turned + 1;
                    if (lines_turned == 8) begin
                        lines_turned = 0;
                        a_turn(a_cell);
                    end
                end else begin
                    lines_turned = 0;
                    if (turned >= 0) written_while_shown = written_while_shown + 1;
                end
                seen[offset] = data_out;
            end else if (turned >= 0) begin
                written_while_shown = written_while_shown + 1;    // the colors
            end
        end
    end

    // The person begins to type at the monitor's first prompt. When the story
    // is done and the cursor shows (the 13th turn), S1, a millisecond later:
    // typing.s has written by then that the cursor shows (SHOWN), and the
    // reset must forget it. When it shows after S1 (the 14th turn), the Mac
    // types.
    integer s1_at = 0;
    always @(posedge clk) begin
        if (!typing && the_mac.prompts == 1) begin
            typing = 1;
            $display("cycle %8d: the Mac hears the first prompt; the person begins to type", cycle);
        end
        if (typed_all && turns == 13 && s1_at == 0 && cycle >= turn_at[12] + 12_600) begin
            s1 = 1;
            s1_at = cycle;
            turned = -1;            // the screen is about to be cleared: the eye forgets the cell
            lines_turned = 0;
            $display("cycle %8d: the person is done, and the cursor shows; S1 is pressed", cycle);
        end
        if (s1 && cycle >= s1_at + 100) begin
            s1 = 0;
            heard_from = the_mac.count;
            last_event = cycle;
            $display("cycle %8d: S1 is let go", cycle);
        end
        if (!go && turns == 14) begin
            go = 1;
            $display("cycle %8d: the cursor shows again; the Mac begins to type", cycle);
        end
    end

    // The end: the Mac is done, the cursor shows at the last prompt, then hides.
    integer k, different, first_difference, fh;
    integer turns_wrong;
    integer cells_shown, cells_hidden;
    initial begin
        wait (done && turns >= 16 && turned >= 0);
        @(negedge clk);
        replay;
        $display("cycle %8d: the cursor shows at the last prompt; the screen, read cell by cell (# a cell turned over):", cycle);
        read_screen(turned);
        cells_shown = wrong_cells;
        $display("    %0d cells of 1,000 differ from the expected screen with the cursor at row %0d, column %0d", cells_shown, turned / 40, turned % 40);
        wait (turns >= 17);
        @(negedge clk);
        replay;
        $display("cycle %8d: the cursor is hidden; the screen, read cell by cell:", cycle);
        read_screen(-1);
        cells_hidden = wrong_cells;
        $display("    %0d cells of 1,000 differ from the expected screen", cells_hidden);
        if (cells_shown != 0 || cells_hidden != 0) errors = errors + 1;
        #(200_000);
        @(negedge clk);

        $display("what the Mac heard (%0d bytes; %0d expected):", the_mac.count, expected_length);
        $write("    |");
        for (k = 0; k < the_mac.count; k = k + 1) begin
            if (the_mac.heard[k] == 10) $write("\n    |");
            else if (the_mac.heard[k] == 8) $write("^H");
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        fh = $fopen("heard-cursor.txt", "wb");
        for (k = 0; k < the_mac.count; k = k + 1) $fwrite(fh, "%c", the_mac.heard[k]);
        $fclose(fh);
        different = 0;
        first_difference = -1;
        for (k = 0; k < expected_length; k = k + 1)
            if (k >= the_mac.count || the_mac.heard[k] !== expected[k]) begin
                different = different + 1;
                if (first_difference < 0) first_difference = k;
            end
        $display("against the conversation written by hand: %0d of %0d bytes differ%0s", different, expected_length,
                 the_mac.count > expected_length ? ", and the Mac heard more" : "");
        if (first_difference >= 0) $display("    the first at byte %0d", first_difference);
        if (different != 0 || the_mac.count != expected_length) errors = errors + 1;

        // The turns, against the list written by hand.
        turns_wrong = 0;
        fh = $fopen("turns.txt", "w");
        $display("the turns of the cursor (%0d; %0d expected):", turns, wanted);
        for (k = 0; k < turns && k < 64; k = k + 1) begin
            $fwrite(fh, "%0d %0s %0d %0d %0d %0d\n", turn_at[k], turn_kind[k] == 1 ? "show" : turn_kind[k] == 0 ? "hide" : "other",
                    turn_cell[k] / 40, turn_cell[k] % 40, turn_since[k], turn_heard[k]);
            if (k >= wanted || turn_kind[k] != want_kind[k] || turn_cell[k] != want_row[k] * 40 + want_col[k] ||
                turn_place[k] != turn_cell[k] ||
                (want_when[k] == QUARTER && (turn_since[k] < QUARTER_CYCLES - WITHIN ||
                                             turn_since[k] > QUARTER_CYCLES + WITHIN)) ||
                (want_when[k] == KEY && turn_since[k] > 20_000)) begin
                turns_wrong = turns_wrong + 1;
                $display("    %2d wrong: %0s at row %0d, column %0d (the next letter: row %0d, column %0d), %0d cycles after; expected %0s at row %0d, column %0d, %0s",
                         k + 1, turn_kind[k] == 1 ? "shows" : turn_kind[k] == 0 ? "hides" : "other", turn_cell[k] / 40, turn_cell[k] % 40,
                         turn_place[k] / 40, turn_place[k] % 40, turn_since[k],
                         k < wanted && want_kind[k] == 1 ? "shows" : "hides", k < wanted ? want_row[k] : 0, k < wanted ? want_col[k] : 0,
                         k < wanted && want_when[k] == KEY ? "right after a key or a byte" : "a quarter of a second after");
            end else begin
                $display("    %2d %0s at row %0d, column %0d, where the next letter goes: %0s (%0d cycles)", k + 1,
                         turn_kind[k] == 1 ? "shows" : "hides", turn_cell[k] / 40, turn_cell[k] % 40,
                         want_when[k] == KEY ? "right after a key or a byte" : "a quarter of a second after", turn_since[k]);
            end
        end
        $fclose(fh);
        if (turns != wanted || turns_wrong != 0) errors = errors + 1;
        $display("written on the screen while a cell showed turned over: %0d; turned over while a key was held down: %0d",
                 written_while_shown, shown_while_held);
        if (written_while_shown != 0 || shown_while_held != 0) errors = errors + 1;

        if (errors == 0)
            $display("PASS: cursor, it showed after a quarter of a second of waiting, blinked twice a second, hid before each character, never while a key was held down, and left no cell turned over, by cycle %0d",
                     cycle);
        else
            $display("FAIL: cursor, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        wait (cycle == LIMIT);
        $display("FAIL: cursor, not finished after %0d cycles (phase %0d; %0d turns; the Mac had typed %0d lines); it heard:",
                 LIMIT, phase, turns, the_mac.lines);
        $write("    |");
        for (k = 0; k < the_mac.count; k = k + 1) begin
            if (the_mac.heard[k] == 10) $write("\n    |");
            else if (the_mac.heard[k] == 8) $write("^H");
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        $finish;
    end
endmodule
