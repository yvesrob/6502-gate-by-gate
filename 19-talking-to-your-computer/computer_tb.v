// Chapter 19, test bench for the whole computer, with the program of the
// board, load.s, and a Mac: mac.v, which sends maze.s as tools/send.py does,
// line by line, on the wire rx, and checks that each line comes back on tx.
//
// The test bench reads the screen, cell by cell, as an eye would, twice: when
// load.s starts listening (its four lines of text), and when the Mac has sent
// everything (the text, and every line that came, as load.s wrote it). Each
// cell must hold the letter the test bench expects: it keeps a screen of its
// own, where it types the same characters with the same rules as the
// console. It checks that the RAM holds maze.bin from $0300, byte for byte.
//
// Then maze.s runs. It tells the Mac "Maze 01, random ACE1". The test bench
// presses S2 when the LEDs show 1, so that the maze is drawn without waiting,
// and when the last cell is drawn it reads the bitmap again: each cell must
// hold the diagonal that the test bench works out with its own random
// numbers. It writes the maze, with \ and /.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         s2    = 0;      // button S2, wired to NMI as on the board
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;
    wire        rx;
    wire        tx;
    reg         go    = 0;      // the Mac may begin
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
        .nmi            (s2),
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

    // The font begins the ROM: the letter for the code C is at cell 8 x (C - 32).
    function [7:0] font;
        input integer code;
        input integer line;
        font = dut.the_rom.cells[8 * (code - 32) + line];
    endfunction

    // The test bench's screen, as in chapter 18: a code for each cell.
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

    // Some text: Verilog keeps a string at the right of its register, with
    // zeros on the left, which are skipped.
    task put_text;
        input [8 * 40 - 1:0] text;
        integer k;
        begin
            for (k = 39; k >= 0; k = k - 1) begin
                if (text[8 * k +: 8] != 0) put(text[8 * k +: 8]);
            end
        end
    endtask

    // What load.s writes first.
    initial begin
        for (n = 0; n < 1000; n = n + 1) screen[n] = 32;
        put_text("Our Own 6502, Gate by Gate");
        put(13);
        put(10);
        put_text("Chapter 19: Talking to Your Computer");
        put(13);
        put(10);
        put(13);
        put(10);
        put_text("Waiting for a program.");
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

    // The maze: the test bench's own random numbers, as maze.s makes them.
    // Each cell must hold \ (bit 0) or / (bit 1), one byte for each line.
    integer    wrong_maze;
    reg [15:0] random;
    task read_maze;
        integer r, c, line, bit_out;
        reg [7:0] expected;
        reg       backslash, slash;
        begin
            wrong_maze = 0;
            random = 16'hACE1;
            for (r = 0; r < 25; r = r + 1) begin
                $write("    |");
                for (c = 0; c < 40; c = c + 1) begin
                    bit_out = random[0];
                    random  = random >> 1;
                    if (bit_out) random = random ^ 16'hB400;
                    backslash = 1;
                    slash     = 1;
                    for (line = 0; line < 8; line = line + 1) begin
                        expected = bit_out ? (8'h01 << line) : (8'h80 >> line);
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== expected) wrong_maze = wrong_maze + 1;
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== (8'h80 >> line)) backslash = 0;
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== (8'h01 << line)) slash = 0;
                    end
                    $write("%c", backslash ? "\\" : slash ? "/" : "?");
                end
                $display("|");
            end
        end
    endtask

    // The program, as the linker wrote it: the RAM must hold it from $0300.
    reg [7:0] maze_bin [0:4095];
    integer   program_length = 0;
    integer   f, ch;
    initial begin
        f = $fopen("maze.bin", "rb");
        ch = $fgetc(f);
        while (ch != -1) begin
            maze_bin[program_length] = ch;
            program_length = program_length + 1;
            ch = $fgetc(f);
        end
        $fclose(f);
    end

    // What maze.s must say first, after the echo.
    localparam [8 * 22 - 1:0] FIRST_WORDS = {"Maze 01, random ACE1", 8'd13, 8'd10};

    localparam LIMIT = 4_000_000;

    integer cycle          = 0;
    integer listening_at   = 0;     // when load.s first looked at the state of the link
    integer done_at        = 0;
    integer maze_at        = 0;     // when the LEDs showed 1
    integer drawn_at       = 0;
    integer stray_writes   = 0;     // writes where nothing should be written
    integer colors_writes  = 0;
    integer late_writes    = 0;     // writes into the program, after it came
    integer sent_bytes     = 0;     // bytes the processor stored at $8010
    integer errors         = 0;
    integer k, wrong_words, wrong_ram;
    reg     finished       = 0;

    always @(posedge clk) begin
        if (step && !finished) begin
            cycle = cycle + 1;
            if (write) begin
                if (address == 16'h8010) sent_bytes = sent_bytes + 1;
                if (address[15:10] == 6'b100111) colors_writes = colors_writes + 1;
                if (address >= 16'h0300 && address < 16'h8000 && done) late_writes = late_writes + 1;
                if (!(address < 16'h0200 || (address >= 16'h0300 && address < 16'h8000) || address == 16'h8000 ||
                      address == 16'h8010 || address[15:10] == 6'b100111 || address[15:13] == 3'b101))
                    stray_writes = stray_writes + 1;
            end

            // load.s looks at the state of the link for the first time: it is
            // listening. Read the screen, and let the Mac begin.
            if (!go && address == 16'h8011 && !write) begin
                listening_at = cycle;
                $display("cycle %7d: load.s listens; the screen:", cycle);
                read_screen;
                $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
                if (wrong_cells != 0) errors = errors + 1;
                if (colors_writes != 1024) begin
                    $display("    %0d writes into the colors, 1024 expected", colors_writes);
                    errors = errors + 1;
                end
                go = 1;
            end

            // The Mac has sent everything, and it all came back: R has just
            // been written, and maze.s begins. Read the screen and the RAM.
            if (done && done_at == 0) begin
                done_at = cycle;
                for (k = 0; k < the_mac.length; k = k + 1) put(the_mac.text[k]);
                $display("cycle %7d: the Mac has sent %0d lines, %0d characters; %0d came back different, %0d late; the screen:",
                         cycle, the_mac.lines, the_mac.length, the_mac.wrong, the_mac.late);
                read_screen;
                $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
                wrong_ram = 0;
                for (k = 0; k < program_length; k = k + 1) begin
                    if (dut.the_ram.cells[16'h0300 + k] !== maze_bin[k]) wrong_ram = wrong_ram + 1;
                end
                $display("    the RAM from $0300: %0d bytes of %0d differ from maze.bin", wrong_ram, program_length);
                if (the_mac.wrong != 0 || the_mac.late != 0 || wrong_cells != 0 || wrong_ram != 0) errors = errors + 1;
            end

            // The LEDs show 1: maze.s has begun its first maze. Press S2.
            if (done && leds == 1 && maze_at == 0) begin
                maze_at = cycle;
                s2 = 1;
                $display("cycle %7d: the LEDs show 1; S2 is pressed for 20 cycles", cycle);
            end
            if (s2 && cycle > maze_at + 20) s2 = 0;

            // The last line of the last cell: the maze is drawn. (clear writes
            // there too, before load.s listens.)
            if (maze_at != 0 && write && address == 16'hBF3F && drawn_at == 0) begin
                drawn_at = cycle;
                finished = 1;
            end
        end
    end

    initial begin
        wait (finished);
        @(negedge clk);
        @(negedge clk);
        $display("cycle %7d: the last cell is drawn; the screen:", drawn_at);
        read_maze;
        $display("    %0d bytes of 8,000 differ from the expected maze; the random number after the 1,000 cells: %h",
                 wrong_maze, random);
        wrong_words = 0;
        for (k = 0; k < 22; k = k + 1) begin
            if (the_mac.heard[the_mac.length + k] !== FIRST_WORDS[8 * (21 - k) +: 8]) wrong_words = wrong_words + 1;
        end
        $display("after the echo, the Mac heard %0d bytes; %0d of the 22 of \"Maze 01, random ACE1\" differ",
                 the_mac.count - the_mac.length, wrong_words);
        $display("load.s listened at cycle %0d; the Mac's %0d characters took %0d cycles;",
                 listening_at, the_mac.length, done_at - listening_at);
        $display("the first maze, with S2: %0d cycles from the LEDs at 1 to the last cell", drawn_at - maze_at);
        $display("%0d bytes sent by the processor, %0d heard by the Mac without their stop bit; %0d writes into the colors, %0d into the program after it came, %0d where nothing should be written",
                 sent_bytes, the_mac.broken, colors_writes, late_writes, stray_writes);
        if (wrong_maze != 0 || wrong_words != 0 || late_writes != 0 || stray_writes != 0 || colors_writes != 1024 ||
            sent_bytes != the_mac.length + 22 || the_mac.broken != 0)
            errors = errors + 1;
        if (errors == 0)
            $display("PASS: computer, load.s took maze.s line by line, every character came back, the RAM holds it, and it drew its maze, by cycle %0d",
                     drawn_at);
        else
            $display("FAIL: computer, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        wait (cycle == LIMIT);
        $display("FAIL: computer, not finished after %0d cycles (the Mac had sent %0d lines)", LIMIT, the_mac.lines);
        $finish;
    end
endmodule
