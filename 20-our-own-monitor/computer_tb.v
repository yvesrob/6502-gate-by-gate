// Chapter 20, test bench for the whole computer, with the monitor in the ROM
// and a Mac, mac.v, which types build/session.txt to it, a line at a time:
// the lines of explore.txt, then maze.s, as tools/send.py sends it.
//
// The test bench checks what the monitor answers: each line it writes that
// shows bytes, such as "C108: 38 44 44 7C 44 44 44 00", must show the bytes
// that the memory holds at those addresses, at the moment the Mac hears the
// line. A line that was typed does not count: it begins with the prompt.
// explore.txt asks for 39 bytes, on 7 lines, and makes one mistake: so many
// lines must show bytes, and one must be a ? alone.
// After some lines it checks the memory itself: the LEDs, the bitmap, the RAM.
// When characters.s has run, it reads the screen cell by cell, as an eye
// would: the screen must show what the Mac heard, as the console writes it,
// with the 95 characters of characters.s after the line that ran it. At the
// end the RAM must hold maze.bin, and maze.s must say "Maze 01, random ACE1".
// It writes all that the Mac heard into heard.txt, for the judge in Python.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire        rx;
    wire        tx;
    reg         go    = 1;      // the Mac may begin: it waits for the first prompt
    wire        done;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk            (clk),
        .reset          (1'b0),
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
        .tx             (tx)
    );

    mac the_mac (
        .go   (go),
        .tx   (tx),
        .rx   (rx),
        .done (done)
    );

    // One tick every 40 ns, as for the pixel clock: the Mac's bits are timed
    // in nanoseconds.
    always #20 clk = ~clk;

    // In the chip the memories start at zero; in the simulator they start
    // unknown. The test bench does what the chip does.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // What the processor reads at an address, as the computer answers it.
    function [7:0] memory;
        input [15:0] a;
        memory = (a[15] == 1'b0)          ? dut.the_ram.cells[a[14:0]]      :
                 (a[15:14] == 2'b11)      ? dut.the_rom.cells[a[13:0]]      :
                 (a == 16'h8000)          ? {2'b00, leds}                   :
                 (a[15:10] == 6'b100111)  ? dut.the_colors.cells[a[9:0]]    :
                 (a[15:13] == 3'b101)     ? dut.the_bitmap.cells[a[12:0]]   : 8'h00;
    endfunction

    // A hexadecimal digit, as a character: its value, or 16 if it is none.
    function [4:0] hex;
        input [7:0] c;
        hex = (c >= "0" && c <= "9") ? c - "0" :
              (c >= "A" && c <= "F") ? c - "A" + 10 : 16;
    endfunction

    // The font begins the ROM: the letter for the code C is at cell 8 x (C - 32).
    function [7:0] font;
        input integer code;
        input integer line;
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction

    // The test bench's screen, as in chapters 18 and 19: a code for each cell.
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

    // Read the bitmap cell by cell: each cell must hold the letter of the
    // test bench's screen; the first seven cells of the top row also have the
    // line that A118: FF FF FF FF FF FF FF drew, their last line of pixels.
    // Write what is there: a ? if no letter of the font.
    integer wrong_cells;
    task read_screen;
        integer r, c, line, code, found;
        reg [7:0] expected;
        reg       same;
        begin
            wrong_cells = 0;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c = 0; c < 40; c = c + 1) begin
                    same = 1;
                    for (line = 0; line < 8; line = line + 1) begin
                        expected = (r == 0 && c < 7 && line == 7) ? 8'hFF : font(screen[r * 40 + c], line);
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== expected) same = 0;
                    end
                    if (!same) wrong_cells = wrong_cells + 1;
                    found = 0;
                    for (code = 32; code < 127 && found == 0; code = code + 1) begin
                        same = 1;
                        for (line = 0; line < ((r == 0 && c < 7) ? 7 : 8); line = line + 1) begin
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

    // The programs, as the linker wrote them.
    reg [7:0] maze_bin [0:4095];
    reg [7:0] characters_bin [0:255];
    integer   maze_length = 0;
    integer   characters_length = 0;
    integer   f, ch;
    initial begin
        f = $fopen("maze.bin", "rb");
        ch = $fgetc(f);
        while (ch != -1) begin
            maze_bin[maze_length] = ch;
            maze_length = maze_length + 1;
            ch = $fgetc(f);
        end
        $fclose(f);
        f = $fopen("characters.bin", "rb");
        ch = $fgetc(f);
        while (ch != -1) begin
            characters_bin[characters_length] = ch;
            characters_length = characters_length + 1;
            ch = $fgetc(f);
        end
        $fclose(f);
    end

    // What maze.s must say first.
    localparam [8 * 22 - 1:0] FIRST_WORDS = {"Maze 01, random ACE1", 8'd13, 8'd10};

    localparam LIMIT = 10_000_000;

    integer cycle          = 0;
    integer errors         = 0;
    integer stray_writes   = 0;     // writes where nothing should be written
    integer colors_writes  = 0;
    integer sent_bytes     = 0;     // bytes the processor stored at $8010
    integer k, j, wrong, a;
    reg     finished       = 0;

    always @(posedge clk) begin
        if (step && !finished) begin
            cycle = cycle + 1;
            if (write) begin
                if (address == 16'h8010) sent_bytes = sent_bytes + 1;
                if (address[15:10] == 6'b100111) colors_writes = colors_writes + 1;
                if (!(address < 16'h8000 || address == 16'h8000 || address == 16'h8010 ||
                      address[15:10] == 6'b100111 || address[15:13] == 3'b101))
                    stray_writes = stray_writes + 1;
            end
        end
    end

    // The first prompt that the Mac hears: the monitor waits for a key.
    reg prompted = 0;
    always @(posedge clk) begin
        if (!prompted && the_mac.prompts == 1) begin
            prompted = 1;
            $display("cycle %7d: the Mac hears the first prompt; the monitor waits for a key", cycle);
        end
    end

    // Each line the Mac hears: if it shows bytes, they must be the memory's.
    integer seen      = 0;      // bytes of heard looked at
    integer line_from = 0;      // where the line being heard began
    integer shown     = 0;      // lines that show bytes
    integer bytes_shown = 0;
    integer wrong_shown = 0;
    integer mistakes  = 0;      // lines that are a ? alone
    integer length, value, digit;
    reg     shows;
    always @(posedge clk) begin
        while (seen < the_mac.count) begin
            if (the_mac.heard[seen] == 10) begin
                length = seen - 1 - line_from;      // without the 13 and 10
                shows = (length >= 8 && (length - 5) % 3 == 0 && the_mac.heard[line_from + 4] == ":");
                for (k = 0; k < 4 && shows; k = k + 1)
                    if (hex(the_mac.heard[line_from + k]) == 16) shows = 0;
                if (shows) begin
                    a = 0;
                    for (k = 0; k < 4; k = k + 1) a = a * 16 + hex(the_mac.heard[line_from + k]);
                    wrong = 0;
                    for (j = 0; j < (length - 5) / 3; j = j + 1) begin
                        value = hex(the_mac.heard[line_from + 6 + 3 * j]) * 16 + hex(the_mac.heard[line_from + 7 + 3 * j]);
                        if (the_mac.heard[line_from + 5 + 3 * j] != " " || value !== memory(a + j)) wrong = wrong + 1;
                    end
                    shown = shown + 1;
                    bytes_shown = bytes_shown + (length - 5) / 3;
                    wrong_shown = wrong_shown + wrong;
                end
                if (length == 1 && the_mac.heard[line_from] == "?") mistakes = mistakes + 1;
                line_from = seen + 1;
            end
            seen = seen + 1;
        end
    end

    // After some lines of explore.txt, the memory.
    integer lines_before = 0;
    integer at_line [0:255];
    always @(posedge clk) begin
        if (the_mac.lines != lines_before) begin
            lines_before = the_mac.lines;
            at_line[lines_before] = cycle;
            case (lines_before)
                2: begin    // 8000: 2A
                    $display("cycle %7d: after \"8000: 2A\", the LEDs show %h", cycle, leds);
                    if (leds !== 6'h2A) errors = errors + 1;
                end
                4: begin    // A118: FF FF FF FF FF FF FF
                    wrong = 0;
                    for (k = 0; k < 7; k = k + 1) if (dut.the_bitmap.cells[16'h0118 + k] !== 8'hFF) wrong = wrong + 1;
                    if (dut.the_bitmap.cells[16'h011F] !== 8'h00) wrong = wrong + 1;
                    $display("cycle %7d: after \"A118: FF ...\", %0d of the bytes $A118 to $A11F differ from FF x 7, 00", cycle, wrong);
                    if (wrong != 0) errors = errors + 1;
                end
                6: begin    // : A9 0D ...
                    wrong = 0;
                    for (k = 0; k < characters_length; k = k + 1)
                        if (dut.the_ram.cells[16'h0300 + k] !== characters_bin[k]) wrong = wrong + 1;
                    $display("cycle %7d: after the two lines of characters.s, %0d bytes of %0d from $0300 differ from characters.bin",
                             cycle, wrong, characters_length);
                    if (wrong != 0) errors = errors + 1;
                end
                8: begin    // 0300R: characters.s has run, and come back
                    for (k = 0; k < 1000; k = k + 1) screen[k] = 32;
                    col = 0;
                    row = 0;
                    for (k = 0; k < the_mac.count; k = k + 1) begin
                        put(the_mac.heard[k]);
                        if (k == the_mac.typed_at[7] + 6) begin     // after the echo of 0300R
                            for (j = 32; j < 127; j = j + 1) put(j);
                            put(13);
                            put(10);
                        end
                    end
                    $display("cycle %7d: characters.s has come back; the screen:", cycle);
                    read_screen;
                    $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
                    if (wrong_cells != 0) errors = errors + 1;
                end
                10: begin   // 1234R, then Escape: nothing ran
                    $display("cycle %7d: after \"1234R\" and Escape, %0d writes into the colors (the reset paints all 1,024)",
                             cycle, colors_writes);
                    if (colors_writes != 1024) errors = errors + 1;
                end
                11: begin   // 05FE: 01 02 03 04
                    wrong = 0;
                    for (k = 0; k < 4; k = k + 1) if (dut.the_ram.cells[16'h05FE + k] !== k + 1) wrong = wrong + 1;
                    $display("cycle %7d: after \"05FE: 01 02 03 04\", across a page, %0d of the 4 bytes differ", cycle, wrong);
                    if (wrong != 0) errors = errors + 1;
                end
            endcase
        end
    end

    // The end: the RAM after the Mac has sent maze.s, and what maze.s says.
    integer words_at;
    integer wrong_words;
    integer wrong_ram;
    integer fh;
    initial begin
        wait (done);
        @(negedge clk);
        wrong_ram = 0;
        for (k = 0; k < maze_length; k = k + 1)
            if (dut.the_ram.cells[16'h0300 + k] !== maze_bin[k]) wrong_ram = wrong_ram + 1;
        $display("cycle %7d: the Mac has typed %0d lines; %0d late; the RAM from $0300: %0d bytes of %0d differ from maze.bin",
                 cycle, the_mac.lines, the_mac.late, wrong_ram, maze_length);
        if (wrong_ram != 0 || the_mac.late != 0) errors = errors + 1;
        words_at = the_mac.said_from;
        wait (the_mac.count >= words_at + 22 || cycle >= LIMIT);
        #(100_000);
        wrong_words = 0;
        for (k = 0; k < 22; k = k + 1)
            if (the_mac.heard[words_at + k] !== FIRST_WORDS[8 * (21 - k) +: 8]) wrong_words = wrong_words + 1;
        finished = 1;

        // What the Mac heard, from the start, as a terminal would show it.
        $display("what the Mac heard, from the start (%0d bytes):", the_mac.count);
        $write("    |");
        for (k = 0; k < the_mac.count; k = k + 1) begin
            if (the_mac.heard[k] == 10) $write("\n    |");
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        fh = $fopen("heard.txt", "wb");
        for (k = 0; k < the_mac.count; k = k + 1) $fwrite(fh, "%c", the_mac.heard[k]);
        $fclose(fh);

        $display("the cycle at which the Mac is done with each line, its last prompt heard:");
        for (k = 1; k < the_mac.lines; k = k + 1)
            $display("    line %2d: cycle %7d, %6d cycles after the line before", k, at_line[k],
                     at_line[k] - (k == 1 ? 0 : at_line[k - 1]));
        $display("%0d lines showed %0d bytes; %0d of them differ from the memory; %0d line(s) answered with a ?",
                 shown, bytes_shown, wrong_shown, mistakes);
        $display("after the echo of 0300R, %0d of the 22 bytes of \"Maze 01, random ACE1\" differ", wrong_words);
        $display("%0d bytes sent by the processor, %0d heard by the Mac, %0d without their stop bit; %0d writes into the colors, %0d where nothing should be written",
                 sent_bytes, the_mac.count, the_mac.broken, colors_writes, stray_writes);
        // explore.txt asks for 39 bytes, on 7 lines: C108.C10F, 8000, 0300.0315 and
        // 05FC.0603; and one line is a mistake, 0300X.
        if (wrong_shown != 0 || shown != 7 || bytes_shown != 39 || mistakes != 1 || wrong_words != 0 || stray_writes != 0 || colors_writes != 1024 ||
            sent_bytes != the_mac.count || the_mac.broken != 0)
            errors = errors + 1;
        if (errors == 0)
            $display("PASS: computer, the monitor answered every line of explore.txt as the memory says, stored and ran characters.s, took maze.s from the Mac and ran it, by cycle %0d",
                     cycle);
        else
            $display("FAIL: computer, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        wait (cycle == LIMIT);
        $display("FAIL: computer, not finished after %0d cycles (the Mac had typed %0d lines); it heard:", LIMIT, the_mac.lines);
        $write("    |");
        for (k = 0; k < the_mac.count; k = k + 1) begin
            if (the_mac.heard[k] == 10) $write("\n    |");
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        $finish;
    end
endmodule
