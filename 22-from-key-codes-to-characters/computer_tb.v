// Chapter 22, test bench for the whole computer, with the monitor in the ROM,
// a keyboard and a Mac. First someone types to the monitor on the keyboard:
// ch9350.v plays the keyboard's module, and sends on the wire keyboard what a
// US keyboard says while the lines of its story are typed. Then the Mac,
// mac.v, types build/readback.txt: lines that show what the keyboard stored.
// The Mac listens all along, on tx: the monitor sends it everything it writes.
//
// The test bench checks:
//   - what the Mac heard, byte for byte, against the conversation written
//     below, by hand, from the names of the keys in the USB's tables: each
//     key typed must come back as its character, a held key must repeat;
//   - each line that shows bytes, such as "C108: 38 44 44 7C 44 44 44 00":
//     they must be the bytes the memory holds;
//   - the LEDs and the RAM, after the lines that store;
//   - when the key held down gave its character again, in cycles: half a
//     second, then a twentieth of a second, at 12.6 million cycles a second;
//   - the screen, cell by cell, as an eye would: it must show what the Mac
//     heard, as the console writes it, a backspace moving back one cell: a
//     character rubbed out must be gone, even from the end of the row above.
//     It is read 200 microseconds after the last prompt: the cursor only
//     shows after a quarter of a second of waiting (typing.s; cursor_tb
//     watches it), and the person never stops that long here, so no cell is
//     turned over.
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
        .keyboard       (keyboard)
    );

    ch9350 module_and_keyboard (
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

    // One tick every 40 ns, as for the pixel clock: the bits of the Mac and
    // of the module are timed in nanoseconds.
    always #20 clk = ~clk;

    // In the chip the memories start at zero; in the simulator they start
    // unknown. The test bench does what the chip does.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.the_colors.cells[n] = 8'h00;
    end

    // The conversation the Mac must hear, written by hand: the monitor's
    // title, then each line as the keys typed it, and the monitor's answers.
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
    task say_line(input [8 * 48 - 1:0] what);   // and a carriage return and a line feed
        begin
            say(what);
            say({8'd13, 8'd10});
        end
    endtask
    task rub_out;                               // a character rubbed out: 8, a space, 8
        begin
            say({8'd8, " ", 8'd8});
        end
    endtask
    initial begin
        say_line("Our Own 6502, Gate by Gate");
        say_line("Chapter 22: From Key Codes to Characters");
        // On the keyboard:
        say("*"); say_line("C108.C10F");                    // small letters come back as capitals
        say_line("C108: 38 44 44 7C 44 44 44 00");
        say("*"); say_line("8000: 15");                     // Shift and ; give the colon
        say("*"); say_line("0500: ABCD");                   // b went down while a was still down; c and d together
        say("*"); say("0500X"); rub_out; say_line("");      // Backspace: back, a space, back
        say_line("0500: CD");
        say("*"); say("1234R"); say_line("\\");             // Backspace on the empty line: nothing
        say("*"); say("ASDFGH"); say_line("\\");            // j, one key too many, gave nothing
        say("*"); say_line("0400: 111 22");                 // 1 held down: twice more
        say("*"); say("0600:11 22 33 44 55 66 77 88 99 AA BB X");   // X in the last column
        rub_out; say("CC");                                 // rubbed out from the next row
        rub_out; rub_out; rub_out; rub_out; rub_out;        // Backspace held down: five
        say_line("BB CC");
        // On the Mac:
        say("*"); say_line("\\");                           // it begins with Escape
        say("*"); say_line("0400.0401");
        say_line("0400: 11 22");
        say("*"); say_line("0500");
        say_line("0500: CD");
        say("*"); say_line("8000");
        say_line("8000: 15");
        say("*");
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

    // The test bench's screen, as in chapters 18 to 21: a code for each cell.
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
                // The backspace: back one cell; from the first column, to the
                // last cell of the row above; from the top left, nowhere.
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
        reg       same;
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

    localparam LIMIT = 50_000_000;

    integer cycle          = 0;
    integer errors         = 0;
    integer stray_writes   = 0;     // writes where nothing should be written
    integer sent_bytes     = 0;     // bytes the processor stored at $8010
    integer taken          = 0;     // bytes the processor took from the queue
    integer most           = 0;     // the most bytes that waited in the queue at once
    integer waiting_now;
    integer k, j, wrong, a;
    reg     finished       = 0;

    always @(posedge clk) begin
        if (step && !finished) begin
            cycle = cycle + 1;
            if (write) begin
                if (address == 16'h8010) sent_bytes = sent_bytes + 1;
                if (!(address < 16'h8000 || address == 16'h8000 || address == 16'h8010 ||
                      address[15:10] == 6'b100111 || address[15:13] == 3'b101))
                    stray_writes = stray_writes + 1;
            end
            if (!write && address == 16'h8020) taken = taken + 1;
        end
        waiting_now = (dut.keyboard_queue.in - dut.keyboard_queue.out) & 255;
        if (waiting_now > most) most = waiting_now;
    end

    // When each byte was heard by the Mac, in cycles.
    integer heard_at [0:1023];
    integer stamped = 0;
    always @(posedge clk) begin
        while (stamped < the_mac.count && stamped < 1024) begin
            heard_at[stamped] = cycle;
            stamped = stamped + 1;
        end
    end

    // The person begins to type at the monitor's first prompt; the Mac, when
    // the person is done and the monitor has answered the last line.
    always @(posedge clk) begin
        if (!typing && the_mac.prompts == 1) begin
            typing = 1;
            $display("cycle %8d: the Mac hears the first prompt; the person begins to type", cycle);
        end
        if (typed_all && !go && the_mac.prompts == 9) begin
            go = 1;
            $display("cycle %8d: the keyboard is done, and the monitor has answered; the Mac begins to type", cycle);
        end
    end

    // Each line the Mac hears: if it shows bytes, they must be the memory's.
    integer seen      = 0;      // bytes of heard looked at
    integer line_from = 0;      // where the line being heard began
    integer shown     = 0;      // lines that show bytes
    integer bytes_shown = 0;
    integer wrong_shown = 0;
    integer length, value;
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
                line_from = seen + 1;
            end
            seen = seen + 1;
        end
    end

    // The end: when the Mac has typed its lines and heard the last answer,
    // the thirteenth prompt.
    integer different;
    integer first_difference;
    integer ones;
    integer one_at [0:7];
    integer fh;
    initial begin
        wait (done);
        wait (the_mac.count >= expected_length || the_mac.prompts >= 13 || cycle >= LIMIT);
        #(200_000);
        @(negedge clk);
        finished = 1;

        $display("what the Mac heard (%0d bytes; %0d expected):", the_mac.count, expected_length);
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

        // The key 1 held down: each 1 of "0400: 111", and when the Mac heard it.
        ones = 0;
        for (k = 0; k < the_mac.count; k = k + 1)
            if (the_mac.heard[k] == "1" && k > 6 && the_mac.heard[k - 6] == "0" && the_mac.heard[k - 5] == "4" &&
                the_mac.heard[k - 2] == ":" && ones == 0) begin
                for (j = k; j < k + 8 && the_mac.heard[j] == "1"; j = j + 1) begin
                    one_at[ones] = heard_at[j];
                    ones = ones + 1;
                end
            end
        $display("the key 1 held down gave %0d characters; the Mac heard them at cycles:", ones);
        for (k = 0; k < ones; k = k + 1)
            if (k == 0) $display("    %9d", one_at[k]);
            else        $display("    %9d, %0d cycles after the one before: %0.4f s at 12.6 MHz", one_at[k],
                                 one_at[k] - one_at[k - 1], (one_at[k] - one_at[k - 1]) / 12.6e6);
        // Half a second is 6,300,000 cycles, a twentieth 630,000: within 1 %.
        if (ones != 3 || one_at[1] - one_at[0] < 6_237_000 || one_at[1] - one_at[0] > 6_363_000 ||
            one_at[2] - one_at[1] < 623_700 || one_at[2] - one_at[1] > 636_300)
            errors = errors + 1;

        wrong = 0;
        if (leds !== 6'h15) wrong = wrong + 1;
        if (dut.the_ram.cells[16'h0400] !== 8'h11) wrong = wrong + 1;
        if (dut.the_ram.cells[16'h0401] !== 8'h22) wrong = wrong + 1;
        if (dut.the_ram.cells[16'h0500] !== 8'hCD) wrong = wrong + 1;
        // The line with the mistake rubbed out: $11, $22, ... $CC from $0600.
        for (k = 0; k < 12; k = k + 1) if (dut.the_ram.cells[16'h0600 + k] !== 8'h11 * (k + 1)) wrong = wrong + 1;
        $display("the LEDs show %h; $0400 and $0401 hold %h %h, $0500 holds %h; $0600 to $060B hold %h %h %h %h %h %h %h %h %h %h %h %h: %0d wrong",
                 leds, dut.the_ram.cells[16'h0400], dut.the_ram.cells[16'h0401], dut.the_ram.cells[16'h0500],
                 dut.the_ram.cells[16'h0600], dut.the_ram.cells[16'h0601], dut.the_ram.cells[16'h0602], dut.the_ram.cells[16'h0603],
                 dut.the_ram.cells[16'h0604], dut.the_ram.cells[16'h0605], dut.the_ram.cells[16'h0606], dut.the_ram.cells[16'h0607],
                 dut.the_ram.cells[16'h0608], dut.the_ram.cells[16'h0609], dut.the_ram.cells[16'h060A], dut.the_ram.cells[16'h060B], wrong);
        if (wrong != 0) errors = errors + 1;

        $display("%0d lines showed %0d bytes; %0d of them differ from the memory", shown, bytes_shown, wrong_shown);
        if (wrong_shown != 0 || shown != 5 || bytes_shown != 13) errors = errors + 1;

        for (k = 0; k < 1000; k = k + 1) screen[k] = 32;
        col = 0;
        row = 0;
        for (k = 0; k < the_mac.count; k = k + 1) put(the_mac.heard[k]);
        $display("the screen:");
        read_screen;
        $display("    %0d cells of 1,000 differ from the expected screen", wrong_cells);
        if (wrong_cells != 0) errors = errors + 1;

        $display("the module sent %0d bytes, %0d reports of the keyboard; the processor took %0d; at most %0d waited in the queue",
                 module_and_keyboard.bytes, module_and_keyboard.reports, taken, most);
        $display("bytes skipped: %0d; keys held: %h %h %h %h %h %h, repeating: %h",
                 dut.the_ram.cells[8'hE8], dut.the_ram.cells[8'hE9], dut.the_ram.cells[8'hEA], dut.the_ram.cells[8'hEB],
                 dut.the_ram.cells[8'hEC], dut.the_ram.cells[8'hED], dut.the_ram.cells[8'hEE], dut.the_ram.cells[8'hEF]);
        $display("%0d bytes sent by the processor, %0d heard by the Mac, %0d without their stop bit; %0d writes where nothing should be written",
                 sent_bytes, the_mac.count, the_mac.broken, stray_writes);
        if (taken != module_and_keyboard.bytes || stray_writes != 0 || sent_bytes != the_mac.count || the_mac.broken != 0 ||
            dut.the_ram.cells[8'hE8] != 0 || dut.the_ram.cells[8'hEF] != 0)
            errors = errors + 1;
        for (k = 8'hE9; k <= 8'hEE; k = k + 1) if (dut.the_ram.cells[k] != 0) errors = errors + 1;

        if (errors == 0)
            $display("PASS: computer, every key typed on the keyboard came back as its character, Backspace rubbed out, the key held down repeated in time, the Mac read back what the keyboard stored, by cycle %0d",
                     cycle);
        else
            $display("FAIL: computer, %0d check(s) wrong", errors);
        $finish;
    end

    initial begin
        wait (cycle == LIMIT);
        $display("FAIL: computer, not finished after %0d cycles (phase %0d; the Mac had typed %0d lines); it heard:", LIMIT, phase, the_mac.lines);
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
