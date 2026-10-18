// Chapter 23, test bench for the whole computer, typed to on the keyboard:
// the finished machine of volume 1. ch9350.v plays the keyboard's module and
// someone who types build/keyboard.txt on a US keyboard: D000R to the monitor,
// the two Returns, a program that draws a wave of stars, RUN; NEW, a program
// that never ends, RUN, then S2 on the board; LIST; POKE 32768,63. Before each
// line the person waits for the computer to be ready, as on the screen; the
// test bench tells it so, from what the computer says, which put also sends
// to the Mac: the monitor's prompt, * at the start of a line; the BASIC's OK
// and its line feed; a question mark and a space; or, after a line that
// begins with a digit, 1 ms of silence. The Mac only listens.
//
// It checks what it can work out by itself: each line comes back on the
// screen as typed, in capitals; S2 stops the program, with BREAK IN 10; LIST
// shows it; POKE 32768,63 lights the six LEDs; the BASIC writes only where it
// should (computer_tb's places); and at the end, read cell by cell, the screen
// shows all that the Mac heard. It writes what the Mac heard in
// heard-keyboard.txt, for the judge in Python.
// Since the evening of 17 October 2026 (chapter 22: a real backspace),
// keyboard.txt also takes mistakes back: I=1 rubbed out for I=0, as the
// screen shows it; two Backspaces on an empty line, which write nothing; and
// a PRINT longer than a row whose mistake, in the last column, is rubbed out
// from the first column of the next row, after the screen has scrolled. The
// wave of stars then proves that the BASIC kept the line as it was meant.
// Since 18 October 2026 (chapter 22: the cursor), the test bench also
// watches the bitmap as cursor_tb does in chapter 22: each byte written there
// is compared with the one that was there, and eight in a row, lines 0 to 7
// of one cell, each turned into its opposite, are a turn of the cursor. The
// person waits 300 ms before the Return of the RUN of the wave (^W in
// keyboard.txt): the cursor must show after RUN, hide at the Return, and not
// turn while the program runs; and at the end, after the last OK, it must
// show a quarter of a second later where the next line begins, then hide.
// Nothing else may be written on the screen while it shows. The screen is
// read twice at the end: while the cursor shows, and once it has hidden.
`timescale 1ns/1ns
module keyboard_tb;
    reg         clk = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_out;
    wire        write;
    wire        tx;
    wire        keyboard;
    wire        s2;
    wire        typed_all;
    wire        typing;
    wire        numbered;
    wire [31:0] lines;
    reg         ready = 0;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk            (clk),
        .reset          (1'b0),
        .step           (step),
        .irq            (1'b0),
        .nmi            (s2),       // S2, pressed by the person
        .leds           (leds),
        .address        (address),
        .data_in        (),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (13'd0),
        .bitmap_byte    (),
        .colors_address (10'd0),
        .colors_byte    (),
        .rx             (1'b1),     // the Mac types nothing
        .tx             (tx),
        .keyboard       (keyboard)
    );

    ch9350 #(.FILE("keyboard.txt")) the_keyboard (
        .go       (1'b1),
        .ready    (ready),
        .tx       (keyboard),
        .s2       (s2),
        .done     (typed_all),
        .typing   (typing),
        .numbered (numbered),
        .lines    (lines)
    );

    always #20 clk = ~clk;

    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // The Mac listens: a falling edge is a start bit; then the middle of each bit.
    localparam BIT = 8746;
    reg [7:0]  heard [0:65535];
    integer    count = 0;
    integer    broken = 0;
    reg [63:0] heard_when = 0;
    reg [7:0]  byte_heard;
    integer    k;
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
                heard_when = $time;
            end
        end
    end

    // Is the computer ready for the next line? Not while one is typed; then
    // the line feed after it, and the end of what was heard.
    integer start_at = 0;
    reg     typing_before = 0;
    reg     line_fed;
    integer p;
    always @(posedge clk) begin
        if (typing && !typing_before) start_at = count;
        typing_before = typing;
        line_fed = 0;
        for (p = start_at; p < count; p = p + 1) if (heard[p] == 10) line_fed = 1;
        ready = !typing && line_fed &&
                ((count >= 2 && heard[count - 2] == 10 && heard[count - 1] == "*") ||
                 (count >= 2 && heard[count - 2] == "?" && heard[count - 1] == " ") ||
                 (count >= 4 && heard[count - 4] == "O" && heard[count - 3] == "K" &&
                                heard[count - 2] == 13 && heard[count - 1] == 10) ||
                 (numbered && $time - heard_when >= 1_000_000));
    end

    // Where the BASIC may write: computer_tb's places.
    integer cycle = 0;
    integer stray_writes = 0;
    integer first_stray = -1;
    always @(posedge clk) begin
        if (step) begin
            cycle = cycle + 1;
            if (write && !((address <= 16'h00DD) ||
                           (address >= 16'h00E0 && address <= 16'h00EF) ||   // the keyboard: chapters 21 and 22
                           (address >= 16'h00F0 && address <= 16'h00FF) ||   // the console, typing.s and its cursor
                           (address >= 16'h0100 && address <= 16'h01FF) ||
                           (address >= 16'h0200 && address <= 16'h027F && lines < 1) ||
                           (address >= 16'h0280 && address <= 16'h0282) ||
                           (address >= 16'h0300 && address <= 16'h7FFF) ||
                           address == 16'h8000 || address == 16'h8010 ||
                           address[15:10] == 6'b100111 || address[15:13] == 3'b101)) begin
                if (first_stray < 0) first_stray = address;
                stray_writes = stray_writes + 1;
            end
        end
    end

    // The eye on the cursor, as in cursor_tb (chapter 22).
    reg [7:0] seen [0:8191];        // the bitmap as the eye last saw it
    initial for (n = 0; n < 8192; n = n + 1) seen[n] = 8'h00;
    integer turned       = -1;      // the cell that shows turned over; -1: none
    integer lines_turned = 0;
    integer turning_cell = -1;
    integer written_while_shown = 0;
    integer shown_while_held    = 0;
    integer last_event   = 0;       // a key goes down or comes up, the Mac hears a byte
    integer last_turn    = 0;
    integer held_before  = 0;
    integer count_before = 0;
    integer offset, a_cell, a_line, since;
    integer turns = 0;
    integer turn_at    [0:15];
    integer turn_kind  [0:15];
    integer turn_cell  [0:15];
    integer turn_since [0:15];
    integer turn_place [0:15];
    integer run_ok = 0;             // when the OK after the RUN of the wave was heard
    always @(posedge clk) begin
        if (turns == 2 && run_ok == 0 && count >= 4 && heard[count - 4] == "O" && heard[count - 3] == "K" &&
            heard[count - 2] == 13 && heard[count - 1] == 10)
            run_ok = cycle;
        if (the_keyboard.held != held_before) begin
            held_before = the_keyboard.held;
            last_event = cycle;
        end
        if (count != count_before) begin
            count_before = count;
            last_event = cycle;
        end
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
                written_while_shown = written_while_shown + 1;
            end
        end
    end

    // The test bench's screen, as in computer_tb.
    function [7:0] font(input integer code, input integer line);
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction
    reg [7:0] screen [0:999];
    integer   col = 0, row = 0;
    task down;
        integer q;
        begin
            if (row < 24) row = row + 1;
            else begin
                for (q = 0; q < 960; q = q + 1) screen[q] = screen[q + 40];
                for (q = 960; q < 1000; q = q + 1) screen[q] = 32;
            end
        end
    endtask
    task put(input integer code);
        begin
            if (code == 13) col = 0;
            else if (code == 10) down;
            else if (code == 8) begin           // the backspace (chapter 22): back one cell
                if (col > 0) col = col - 1;
                else if (row > 0) begin
                    row = row - 1;
                    col = 39;
                end
            end
            else if (code >= 32 && code <= 126) begin
                screen[row * 40 + col] = code;
                col = col + 1;
                if (col == 40) begin
                    col = 0;
                    down;
                end
            end
        end
    endtask
    // Read the screen cell by cell; the cell turned (if not -1) must show its
    // letter turned over. Written: the letter, # an empty cell turned over.
    integer wrong_cells;
    task read_screen(input integer turned_cell);
        integer r, c2, line, code, found;
        reg same, over;
        begin
            wrong_cells = 0;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c2 = 0; c2 < 40; c2 = c2 + 1) begin
                    same = 1;
                    for (line = 0; line < 8; line = line + 1)
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c2] !==
                            (r * 40 + c2 == turned_cell ? ~font(screen[r * 40 + c2], line) : font(screen[r * 40 + c2], line))) same = 0;
                    if (!same) wrong_cells = wrong_cells + 1;
                    found = 0;
                    over = 0;
                    for (code = 32; code < 127 && found == 0; code = code + 1) begin
                        same = 1;
                        for (line = 0; line < 8; line = line + 1)
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c2] !== font(code, line)) same = 0;
                        if (same) found = code;
                        same = 1;
                        for (line = 0; line < 8; line = line + 1)
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c2] !== ~font(code, line)) same = 0;
                        if (same) begin
                            found = code;
                            over = 1;
                        end
                    end
                    $write("%c", found == 0 ? "?" : over ? (found == 32 ? "#" : "%") : found);
                end
                $display("|");
            end
        end
    endtask

    // A turn of the cursor, as the eye sees it: which cell, shown or hidden,
    // how long after the last thing that happened, and where the next letter
    // goes as the test bench's screen says from what the Mac heard.
    integer q2;
    task a_turn(input integer c);
        begin
            for (q2 = 0; q2 < 1000; q2 = q2 + 1) screen[q2] = 32;
            col = 0;
            row = 0;
            for (q2 = 0; q2 < count; q2 = q2 + 1) put(heard[q2]);
            since = cycle - (last_event > last_turn ? last_event : last_turn);
            if (turns < 16) begin
                turn_at[turns]    = cycle;
                turn_cell[turns]  = c;
                turn_since[turns] = since;
                turn_place[turns] = row * 40 + col;
                if (turned < 0) begin
                    turn_kind[turns] = 1;
                    turned = c;
                    if (the_keyboard.held != 0) shown_while_held = shown_while_held + 1;
                end else if (turned == c) begin
                    turn_kind[turns] = 0;
                    turned = -1;
                end else begin
                    turn_kind[turns] = 2;
                end
                $display("cycle %8d: the cell at row %0d, column %0d %0s, %0d cycles after the last thing that happened (%0.4f s)",
                         cycle, c / 40, c % 40, turn_kind[turns] == 1 ? "shows turned over" :
                         turn_kind[turns] == 0 ? "is back as it was" : "turns over WHILE ANOTHER SHOWS", since, since / 12.6e6);
            end
            turns = turns + 1;
            last_turn = cycle;
        end
    endtask

    // Does the Mac hear this text, anywhere?
    function heard_text(input [8 * 96 - 1:0] wanted, input integer size);
        integer a, q, same;
        begin
            heard_text = 0;
            for (a = 0; a + size <= count && !heard_text; a = a + 1) begin
                same = 1;
                for (q = 0; q < size; q = q + 1)
                    if (heard[a + q] !== wanted[8 * (size - 1 - q) +: 8]) same = 0;
                if (same) heard_text = 1;
            end
        end
    endfunction

    integer errors = 0, fh, j;
    integer cells_shown, cells_hidden, run_from, run_to;
    initial begin
        wait (typed_all);
        wait (ready);
        // The last OK, then nobody types: the cursor shows, then hides.
        wait (turns >= 3 && turned >= 0);
        @(negedge clk);
        for (k = 0; k < 1000; k = k + 1) screen[k] = 32;
        col = 0;
        row = 0;
        for (k = 0; k < count; k = k + 1) put(heard[k]);
        $display("cycle %0d: the cursor shows after the last OK; the screen, read cell by cell (# a cell turned over):", cycle);
        read_screen(turned);
        cells_shown = wrong_cells;
        $display("    %0d cells of 1,000 differ from the screen expected from what the Mac heard, the cursor at row %0d, column %0d",
                 cells_shown, turned / 40, turned % 40);
        wait (turns >= 4);
        @(negedge clk);
        $display("cycle %0d: the cursor is hidden; the screen, read cell by cell:", cycle);
        read_screen(-1);
        cells_hidden = wrong_cells;
        $display("    %0d cells of 1,000 differ from the screen expected from what the Mac heard", cells_hidden);
        if (cells_shown != 0 || cells_hidden != 0) errors = errors + 1;
        #(1_000_000);
        $display("what the Mac heard (%0d bytes):", count);
        $write("    |");
        for (k = 0; k < count; k = k + 1) begin
            if (heard[k] == 10) $write("\n    |");
            else if (heard[k] == 8) $write("^H");      // the backspace, shown
            else if (heard[k] != 13) $write("%c", heard[k]);
        end
        $display("");
        fh = $fopen("heard-keyboard.txt", "wb");
        for (k = 0; k < count; k = k + 1) $fwrite(fh, "%c", heard[k]);
        $fclose(fh);

        j = heard_text({"*D000R", 8'd13, 8'd10}, 8) && heard_text({"10 FOR I=1", 8'd8, " ", 8'd8, "0 TO 6.2 STEP .4"}, 29) &&
            heard_text("20 PRINT TAB(19+18*SIN(I));\"*\"", 30) && heard_text("30 NEXT I", 9) &&
            heard_text("10 PRINT MID$(\"/\\\",RND(1)*2+1,1);", 33) && heard_text("20 GOTO 10", 10) &&
            heard_text({"POKE 32768,63", 8'd13, 8'd10}, 15);
        $display("each line typed on the keyboard comes back as typed, in capitals: %0s", j ? "yes" : "NO");
        if (!j) errors = errors + 1;
        // The Backspaces: I=1 rubbed out (above); nothing for the two on an
        // empty line, NEW comes right after OK; the long PRINT: its X, in the
        // last column, rubbed out from the next row, then what it prints.
        j = heard_text({"OK", 8'd13, 8'd10, "NEW", 8'd13, 8'd10}, 9) &&
            heard_text({"PRINT \"ABCDEFGHIJKLMNOPQRSTUVWXYZ012345X", 8'd8, " ", 8'd8, "6\"", 8'd13, 8'd10,
                        "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456", 8'd13, 8'd10}, 82) &&
            !heard_text("_", 1);
        $display("Backspace rubs out, writes nothing on an empty line, and no _ is ever written: %0s", j ? "yes" : "NO");
        if (!j) errors = errors + 1;
        j = heard_text({8'd13, 8'd10, "BREAK IN  10", 8'd13, 8'd10, "OK"}, 18);
        $display("S2 stops the program that never ends, BREAK IN  10, then OK: %0s", j ? "yes" : "NO");
        if (!j) errors = errors + 1;
        j = heard_text({" 10 PRINT MID$(\"/\\\",RND(1)*2+1,1);", 8'd13, 8'd10}, 36) && heard_text({" 20 GOTO 10", 8'd13, 8'd10, "OK"}, 15);
        $display("LIST shows it: %0s", j ? "yes" : "NO");
        if (!j) errors = errors + 1;
        $display("POKE 32768,63: the LEDs show %0d", leds);
        if (leds !== 63) errors = errors + 1;

        // The cursor: four turns, written by hand. After RUN (^W): it shows
        // in column 3, a quarter of a second after the N of RUN came up; it
        // hides at the Return; nothing turns while the program runs, nor while
        // the next lines are typed; after the last OK it shows in column 0,
        // where the next line begins, then hides a quarter of a second later.
        j = (turns == 4 && turn_kind[0] == 1 && turn_kind[1] == 0 && turn_kind[2] == 1 && turn_kind[3] == 0 &&
             turn_cell[0] % 40 == 3 && turn_cell[1] == turn_cell[0] && turn_cell[2] % 40 == 0 && turn_cell[3] == turn_cell[2]);
        for (k = 0; k < turns && k < 16; k = k + 1) begin
            if (turn_place[k] != turn_cell[k]) j = 0;
            if ((k == 1 && turn_since[k] > 20_000) ||
                (k != 1 && (turn_since[k] < 3_087_000 || turn_since[k] > 3_213_000))) j = 0;
        end
        $display("the cursor: %0d turns (4 expected), each where the next letter goes, a quarter of a second after the last thing that happened (within 2 %%), or right after a key: %0s",
                 turns, j ? "yes" : "NO");
        if (!j) errors = errors + 1;
        // How long the wave ran with the cursor hidden: from the Return of RUN to its OK.
        run_from = turns > 1 ? turn_at[1] : 0;
        $display("    the wave ran from the Return of RUN (cycle %0d) to its OK (cycle %0d), %0.4f s, and the cursor did not turn; written on the screen while it showed: %0d; shown while a key was held down: %0d",
                 run_from, run_ok, (run_ok - run_from) / 12.6e6, written_while_shown, shown_while_held);
        if (written_while_shown != 0 || shown_while_held != 0) errors = errors + 1;
        $display("%0d lines typed on the keyboard; %0d bytes heard by the Mac, %0d without their stop bit; %0d writes where nothing should be written",
                 lines, count, broken, stray_writes);
        if (first_stray >= 0) $display("    the first at $%h", first_stray[15:0]);
        if (broken != 0 || stray_writes != 0) errors = errors + 1;
        if (errors == 0)
            $display("PASS: keyboard, the BASIC typed to on the keyboard: a wave of stars, a program stopped by S2, LIST, POKE 32768,63, by cycle %0d",
                     cycle);
        else
            $display("FAIL: keyboard, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        #(64'd5_000_000_000);
        $display("FAIL: keyboard, not finished after 5 s (%0d lines typed); the Mac heard:", lines);
        $write("    |");
        for (k = 0; k < count; k = k + 1) begin
            if (heard[k] == 10) $write("\n    |");
            else if (heard[k] == 8) $write("^H");      // the backspace, shown
            else if (heard[k] != 13) $write("%c", heard[k]);
        end
        $display("");
        $finish;
    end
endmodule
