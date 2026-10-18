// Chapter 23: the keyboard's module from chapters 21 and 22, for the test
// benches, with someone who types a file this time, build/keyboard.txt, as
// mac.v types session.txt. It plays the CH9350 with a US keyboard plugged
// in: it sends frames on its wire, tx, as the chip does on its pin TXD, at
// 115,200 bits a second. The frames are those of the chip's datasheet
// (version 2.3, the frames of state 2):
//   57 AB 01 and the keyboard's 8 bytes    (57 AB 01 00 00 2C 00 00 00 00 00:
//                                           the space bar is down)
// and those that the chip was seen to send when it starts: 57 AB 86, 57 AB 89
// and 57 AB 80 FF.
//
// The person types each character of the file with the key that gives it on
// a US keyboard, and the left Shift when the key needs it: a report when the
// key goes down, one when it comes up, GAP apart. Small letters stay small: the
// BASIC makes them capitals. Two keys that a text file cannot show are written
// as in caret notation: ^? for Backspace, ^[ for Escape; ^^ is the ^ itself.
// Each line feed of the file is typed as Return. ^W is not a key: the person
// waits 300 ms there, looking at the screen, long enough for the cursor of
// chapter 22 to show (it shows after a quarter of a second).
// Before each line the person looks at the screen, and waits until ready is 1
// (the test bench says when the computer is ready); typing is 1 while a line
// is typed. A line [S2] is not typed:
// the person presses S2 on the board instead, 50 ms after the line before,
// without waiting for the computer: s2 is 1 for a millisecond.
// When the file is done, done is 1.
`timescale 1ns/1ns
module ch9350 (
    input  wire go,         // 1: start
    input  wire ready,      // 1: the computer waits for the next line
    output reg  tx   = 1,   // to our computer: 1 when nothing is sent
    output reg  s2   = 0,   // 1: S2 is pressed
    output reg  done = 0,   // 1: everything was typed
    output reg  typing = 0,     // 1: a line is being typed
    output reg  numbered = 0,   // 1: the line being typed begins with a digit
    output integer lines = 0    // lines typed
);
    integer held = 0;               // 1 while a key, other than Shift, is down
    parameter FILE = "keyboard.txt";
    parameter BIT  = 8750;          // ns: 218.75 ticks of 40 ns, a bit at 115,200 with 25.2 MHz
    parameter GAP  = 1_000_000;     // 1 ms between two reports

    reg [7:0] text [0:8191];        // what it types
    integer   length = 0;
    integer   f, c;
    initial begin
        f = $fopen(FILE, "rb");
        if (f == 0) begin
            $display("FAIL: the keyboard cannot read %0s", FILE);
            $finish;
        end
        c = $fgetc(f);
        while (c != -1) begin
            text[length] = c;
            length = length + 1;
            c = $fgetc(f);
        end
        $fclose(f);
    end

    // One byte: the start bit, the eight bits from the lowest, the stop bit.
    task send_byte(input [7:0] value);
        integer b;
        begin
            tx = 0;
            #(BIT);
            for (b = 0; b < 8; b = b + 1) begin
                tx = value[b];
                #(BIT);
            end
            tx = 1;
            #(BIT);
        end
    endtask

    task short_frame(input [7:0] kind);
        begin
            send_byte(8'h57);
            send_byte(8'hAB);
            send_byte(kind);
        end
    endtask

    // A report of the keyboard: the modifier keys, a byte at 0, six codes.
    task report(input [7:0] modifiers, input [7:0] code);
        integer k;
        begin
            held = (code != 0);
            short_frame(8'h01);
            send_byte(modifiers);
            send_byte(8'h00);
            send_byte(code);
            for (k = 1; k < 6; k = k + 1) send_byte(8'h00);
            #(GAP);
        end
    endtask

    // The key of a US keyboard that gives a character, and whether it needs
    // Shift (bit 8). 0: no key.
    function [8:0] key;
        input [7:0] ch;
        begin
            key = 0;
            if (ch >= "a" && ch <= "z") key = 8'h04 + ch - "a";
            else if (ch >= "A" && ch <= "Z") key = 9'h100 | (8'h04 + ch - "A");
            else if (ch >= "1" && ch <= "9") key = 8'h1E + ch - "1";
            else case (ch)
                "0": key = 8'h27;
                13:  key = 8'h28;           // Return
                27:  key = 8'h29;           // Escape
                8:   key = 8'h2A;           // Backspace
                " ": key = 8'h2C;
                "-": key = 8'h2D;   "_": key = 9'h12D;
                "=": key = 8'h2E;   "+": key = 9'h12E;
                "[": key = 8'h2F;   "{": key = 9'h12F;
                "]": key = 8'h30;   "}": key = 9'h130;
                "\\": key = 8'h31;  "|": key = 9'h131;
                ";": key = 8'h33;   ":": key = 9'h133;
                "'": key = 8'h34;   "\"": key = 9'h134;
                "`": key = 8'h35;   "~": key = 9'h135;
                ",": key = 8'h36;   "<": key = 9'h136;
                ".": key = 8'h37;   ">": key = 9'h137;
                "/": key = 8'h38;   "?": key = 9'h138;
                "!": key = 9'h11E;  "@": key = 9'h11F;  "#": key = 9'h120;  "$": key = 9'h121;
                "%": key = 9'h122;  "^": key = 9'h123;  "&": key = 9'h124;  "*": key = 9'h125;
                "(": key = 9'h126;  ")": key = 9'h127;
            endcase
        end
    endfunction

    localparam LEFT_SHIFT = 8'h02;

    // One character: its key down, then up; with Shift down before, and up after.
    reg [8:0] k;
    task type_character(input [7:0] ch);
        begin
            k = key(ch);
            if (k == 0) begin
                $display("ch9350.v: no key for %0d", ch);
            end else if (k[8]) begin
                report(LEFT_SHIFT, 0);
                report(LEFT_SHIFT, k[7:0]);
                report(LEFT_SHIFT, 0);
                report(0, 0);
            end else begin
                report(0, k[7:0]);
                report(0, 0);
            end
        end
    endtask

    integer i;
    reg [7:0] ch;
    reg       line_done;
    initial begin
        wait (go);
        // 7 nanoseconds more, so that the wire never changes at the very moment
        // the clock ticks (as in chapter 22).
        #7;
        short_frame(8'h86);         // the chip starts
        short_frame(8'h80);
        send_byte(8'hFF);
        short_frame(8'h89);
        short_frame(8'h80);
        send_byte(8'hFF);
        #(GAP);
        i = 0;
        while (i < length) begin
            if (i + 3 < length && text[i] == "[" && text[i + 1] == "S" && text[i + 2] == "2" && text[i + 3] == "]") begin
                // S2 on the board, while the program runs.
                #(50_000_000);
                s2 = 1;
                #(1_000_000);
                s2 = 0;
                i = i + 5;              // past [S2] and its line feed
            end else begin
                // The keys of a line, up to its Return or an Escape.
                wait (ready);
                typing = 1;
                numbered = (text[i] >= "0" && text[i] <= "9");
                line_done = 0;
                while (i < length && !line_done) begin
                    ch = text[i];
                    i = i + 1;
                    if (ch == "^" && i < length && text[i] == "W") begin
                        i = i + 1;
                        #(300_000_000);     // ^W: the person waits, and looks
                    end else begin
                        if (ch == "^" && i < length) begin
                            ch = (text[i] == "?") ? 8 : (text[i] == "[") ? 27 : text[i];
                            i = i + 1;
                        end
                        if (ch == 10) ch = 13;
                        type_character(ch);
                        if (ch == 13 || ch == 27) line_done = 1;
                    end
                end
                lines = lines + 1;
                typing = 0;
            end
        end
        done = 1;
    end
endmodule
