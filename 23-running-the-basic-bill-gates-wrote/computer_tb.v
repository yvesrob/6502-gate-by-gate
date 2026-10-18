// Chapter 23, test bench for the whole computer, with the monitor and
// Microsoft's BASIC in the ROM, and a Mac, mac.v, which types
// build/session.txt to it: two lines to the monitor, then a session of BASIC.
// Nobody types on the keyboard here: keyboard_tb does.
//
// The test bench does not know BASIC. It checks what it can work out from
// our computer alone:
//   - the monitor shows the first three bytes of the BASIC as the ROM holds
//     them;
//   - at MEMORY SIZE?, A makes the BASIC say who wrote it (Microsoft's
//     source has the text: WRITTEN BY WEILAND & GATES);
//   - the BASIC finds the end of the memory where the LEDs keep only six bits
//     of the 85 it writes there: it says 32,768 - $0301 = 31999 BYTES FREE,
//     and the LEDs show 21, 85's six low bits;
//   - PEEK(49416) answers the byte of the ROM at $C108, POKE 32768,42 shows
//     42 on the LEDs, PEEK(32768) reads the LEDs back, and 2+2 is 4;
//   - a small letter comes back as a capital;
//   - the BASIC writes only where it should: its page zero, $01 to $DD, the
//     monitor's FAST at $00, the keyboard's $E0 to $EF and $FB to $FF
//     (chapters 21 and 22: the Mac's characters go through typing.s too, and
//     $FF says whether its cursor shows), the console's $F0 to $FA, the stack,
//     USR at $0280 to $0282, the RAM from $0300, the LEDs, the serial link,
//     and the screen through the console; never the monitor's line after D000R;
//   - at the end, read cell by cell as an eye would, the screen shows all
//     that the Mac heard, as the console writes it, a backspace moving back
//     one cell (chapter 22). It is read a millisecond after the last answer:
//     the cursor of chapter 22 only shows after a quarter of a second of
//     waiting, so no cell is turned over yet.
// The rest, what the BASIC answers, the judge compares with the same BASIC
// running in sim65, another 6502, written by others. For that this test bench
// writes all that the Mac heard into heard.txt.
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
        .tx             (tx),
        .keyboard       (1'b1)      // the keyboard's wire, at rest: nobody types on it here
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

    // The test bench's screen, as in chapters 18 to 20: a code for each cell.
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
                // The backspace (chapter 22): back one cell; from the first
                // column, to the last cell of the row above; from the top
                // left, nowhere.
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
                    for (line = 0; line < 8; line = line + 1)
                        if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(screen[r * 40 + c], line)) same = 0;
                    if (!same) wrong_cells = wrong_cells + 1;
                    found = 0;
                    for (code = 32; code < 127 && found == 0; code = code + 1) begin
                        same = 1;
                        for (line = 0; line < 8; line = line + 1)
                            if (dut.the_bitmap.cells[r * 320 + line * 40 + c] !== font(code, line)) same = 0;
                        if (same) found = code;
                    end
                    $write("%c", found ? found : "?");
                end
                $display("|");
            end
        end
    endtask

    // Does the Mac hear this text, anywhere from a place in heard on?
    function heard_text;
        input integer from;
        input [8 * 40 - 1:0] wanted;    // the text, at the right, zeros on its left
        input integer size;
        integer p, q, same;
        begin
            heard_text = 0;
            for (p = from; p + size <= the_mac.count && !heard_text; p = p + 1) begin
                same = 1;
                for (q = 0; q < size; q = q + 1)
                    if (the_mac.heard[p + q] !== wanted[8 * (size - 1 - q) +: 8]) same = 0;
                if (same) heard_text = 1;
            end
        end
    endfunction

    localparam LIMIT = 100_000_000;

    integer cycle          = 0;
    integer errors         = 0;
    integer stray_writes   = 0;     // writes where nothing should be written
    integer led_writes     = 0;
    integer sent_bytes     = 0;     // bytes the processor stored at $8010
    integer first_stray    = -1;
    reg     finished       = 0;

    always @(posedge clk) begin
        if (step && !finished) begin
            cycle = cycle + 1;
            if (write) begin
                if (address == 16'h8010) sent_bytes = sent_bytes + 1;
                if (address == 16'h8000) led_writes = led_writes + 1;
                if (!((address <= 16'h00DD) ||                                  // FAST, and the BASIC's page zero
                      (address >= 16'h00E0 && address <= 16'h00EF) ||           // the keyboard: chapters 21 and 22
                      (address >= 16'h00F0 && address <= 16'h00FA) ||           // the console
                      (address >= 16'h00FB && address <= 16'h00FF) ||           // typing.s, chapter 22, and its cursor
                      (address >= 16'h0100 && address <= 16'h01FF) ||           // the stack
                      (address >= 16'h0200 && address <= 16'h027F && the_mac.lines < 2) ||  // the monitor's line, before D000R
                      (address >= 16'h0280 && address <= 16'h0282) ||           // USR
                      (address >= 16'h0300 && address <= 16'h7FFF) ||           // the program, its variables, its strings
                      address == 16'h8000 || address == 16'h8010 ||             // the LEDs, the serial link
                      address[15:10] == 6'b100111 || address[15:13] == 3'b101)) begin  // the colors, the bitmap
                    if (first_stray < 0) first_stray = address;
                    stray_writes = stray_writes + 1;
                end
            end
        end
    end

    // After some lines, what the test bench can check by itself.
    integer lines_before = 0;
    integer at_line [0:255];
    integer k, j, wrong;
    always @(posedge clk) begin
        if (the_mac.lines != lines_before) begin
            lines_before = the_mac.lines;
            at_line[lines_before] = cycle;
            case (lines_before)
                5: begin    // A, then the two Returns, at MEMORY SIZE? and TERMINAL WIDTH?
                    $display("cycle %8d: the BASIC has started; the LEDs show %0d (85 is %0d in six bits)", cycle, leds, 85 % 64);
                    if (leds !== 85 % 64) errors = errors + 1;
                end
                10: begin   // POKE 32768,42
                    $display("cycle %8d: after POKE 32768,42, the LEDs show %0d", cycle, leds);
                    if (leds !== 42) errors = errors + 1;
                end
            endcase
        end
    end

    // The end.
    integer fh;
    reg [8 * 40 - 1:0] wanted;
    integer checks_wrong;
    integer high_bytes;
    initial begin
        wait (done);
        #(1_000_000);
        finished = 1;

        $display("what the Mac heard, from the start (%0d bytes):", the_mac.count);
        $write("    |");
        for (k = 0; k < the_mac.count; k = k + 1) begin
            if (the_mac.heard[k] == 10) $write("\n    |");
            else if (the_mac.heard[k] == 8) $write("^H");      // the backspace, shown
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        fh = $fopen("heard.txt", "wb");
        for (k = 0; k < the_mac.count; k = k + 1) $fwrite(fh, "%c", the_mac.heard[k]);
        $fclose(fh);
        // Each key the Mac typed, and how many bytes it had heard then: what
        // the computer said in answer to a key comes before the next key.
        fh = $fopen("keys.txt", "w");
        for (k = 0; k < the_mac.keys; k = k + 1) $fwrite(fh, "%0d %0d\n", the_mac.key[k], the_mac.key_at[k]);
        $fclose(fh);

        checks_wrong = 0;
        $sformat(wanted, "D000: %h %h %h", dut.the_rom.cells[14'h1000], dut.the_rom.cells[14'h1001], dut.the_rom.cells[14'h1002]);
        for (k = 0; k < 40; k = k + 1)          // the monitor writes capitals
            if (wanted[8 * k +: 8] >= "a" && wanted[8 * k +: 8] <= "f") wanted[8 * k +: 8] = wanted[8 * k +: 8] - 32;
        j = heard_text(0, wanted, 14);
        $display("the monitor shows the first bytes of the BASIC as the ROM holds them, \"%0s\": %0s", wanted, j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;
        j = heard_text(0, {"MEMORY SIZE? A", 8'd13, 8'd10}, 16) && heard_text(0, "WRITTEN BY WEILAND & GATES", 26);
        $display("at MEMORY SIZE?, A makes the BASIC say who wrote it, \"WRITTEN BY WEILAND & GATES\": %0s", j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;
        $sformat(wanted, " %0d BYTES FREE", 32768 - 16'h0301);
        j = heard_text(0, wanted, 17);
        $display("the BASIC says \"%0s\": %0s", wanted, j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;
        j = heard_text(0, "PRINT 2+2", 9) && heard_text(0, {" 4 ", 8'd13, 8'd10}, 5);
        $display("print 2+2 comes back as PRINT 2+2, and the answer is 4: %0s", j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;
        j = heard_text(0, {"PEEK(32768)", 8'd13, 8'd10, " 21 "}, 17) && heard_text(0, {"PEEK(32768)", 8'd13, 8'd10, " 42 "}, 17);
        $display("PEEK(32768) reads the LEDs back: 21 after the start, 42 after the POKE: %0s", j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;
        $sformat(wanted, " %0d ", dut.the_rom.cells[14'h0108]);
        j = heard_text(0, wanted, 4);
        $display("PEEK(49416) answers the byte of the ROM at $C108, \"%0s\": %0s", wanted, j ? "yes" : "NO");
        if (!j) checks_wrong = checks_wrong + 1;

        for (k = 0; k < 1000; k = k + 1) screen[k] = 32;
        col = 0;
        row = 0;
        for (k = 0; k < the_mac.count; k = k + 1) put(the_mac.heard[k]);
        $display("cycle %8d: the screen at the end:", cycle);
        read_screen;
        $display("    %0d cells of 1,000 differ from the screen expected from what the Mac heard", wrong_cells);

        $display("the cycle at which the Mac is done with each line, the computer ready again:");
        for (k = 1; k <= the_mac.lines; k = k + 1)
            $display("    line %2d: cycle %8d, %8d cycles after the line before", k, at_line[k],
                     at_line[k] - (k == 1 ? 0 : at_line[k - 1]));
        $display("%0d lines typed, %0d answers late; %0d bytes sent by the processor, %0d heard by the Mac, %0d without their stop bit",
                 the_mac.lines, the_mac.late, sent_bytes, the_mac.count, the_mac.broken);
        high_bytes = 0;
        for (k = 0; k < the_mac.count; k = k + 1) if (the_mac.heard[k] > 127) high_bytes = high_bytes + 1;
        $display("%0d bytes heard above 127; %0d writes into the LEDs (the monitor's 0, the BASIC's 85, the POKE's 42); %0d writes where nothing should be written",
                 high_bytes, led_writes, stray_writes);
        if (first_stray >= 0) $display("    the first at $%h", first_stray[15:0]);
        if (checks_wrong != 0 || wrong_cells != 0 || the_mac.late != 0 || sent_bytes != the_mac.count ||
            the_mac.broken != 0 || stray_writes != 0 || led_writes != 3 || high_bytes != 0)
            errors = errors + 1;
        if (errors == 0)
            $display("PASS: computer, the monitor started Microsoft's BASIC, which answered the %0d lines of session.txt, by cycle %0d",
                     the_mac.lines, cycle);
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
            else if (the_mac.heard[k] == 8) $write("^H");      // the backspace, shown
            else if (the_mac.heard[k] != 13) $write("%c", the_mac.heard[k]);
        end
        $display("");
        $finish;
    end
endmodule
