// Chapter 22: the keyboard's module from chapter 21, for the test benches,
// with someone who types to the monitor this time. It plays the CH9350 with a
// keyboard plugged in: it sends frames on its wire, tx, as the chip does on
// its pin TXD, at 115,200 bits a second, while a person types. The frames are
// those of the chip's datasheet (version 2.3, the frames of state 2):
//   57 AB 01 and the keyboard's 8 bytes    (57 AB 01 00 00 2C 00 00 00 00 00:
//                                           the space bar is down)
//   57 AB 02 and the mouse's 4 bytes
//   57 AB 80 and 1 byte
// and those that the chip was seen to send by people who listened to it:
// 57 AB 86, 57 AB 89 and 57 AB 80 FF when it starts, each report several
// times over.
//
// The keyboard is a US one, and the person types lines to the monitor. What
// happens, in order (phase counts the steps):
//   1. the chip starts: 57 AB 86, 57 AB 80 FF, 57 AB 89, 57 AB 80 FF
//   2. c108.c10f and Return; the first key sends its report three times
//      when it goes down and five times when it comes up, the others twice
//   3. 8000: 15 and Return, the colon with the left Shift
//   4. 0500: and the colon with the right Shift; then a goes down, b goes
//      down while a is still down, a comes up, b comes up; a mouse moves
//      in between, and one of its frames carries 57, AB and 01; then c and
//      d go down together, in one report, and d comes up first; Return. The
//      monitor stores CD, the last two digits of ABCD
//   5. 0500x, Backspace, Return
//   6. Backspace, on a line still empty, then 1234r and Escape
//   7. a s d f g h go down one after the other, then j: one key too many,
//      and the keyboard says 01 in the six places; then they all come up,
//      and Escape
//   8. 0400: and the key 1 held down for 575 milliseconds, then 22, Return
//   9. a line longer than a row: 0600:11 22 33 44 55 66 77 88 99 aa bb and
//      a space, then x, a mistake, in the last column; Backspace takes it
//      back from the first column of the next row; then cc, and Backspace
//      held down for 675 milliseconds: it rubs out five characters, back
//      over the end of the row above; then bb cc again, and Return
// Between two reports it waits GAP; after a key, as long again. When
// everything is sent, done is 1. With QUICK at 1, only steps 1, 2 and 3
// happen: board_tb asks for that, to be shorter.
//
// With PAUSES at 1, the person tells another story instead, for cursor_tb:
// they stop to think now and then, longer than a quarter of a second, and
// the cursor shows (typing.s). What happens, in order:
//   1. the chip starts, as above
//   2. the left Shift alone, held down for 850 ms, then c
//   3. 300 ms, then Backspace
//   4. 300 ms, then 8000; 300 ms, then Return
//   5. the key 0 held down for 530 ms
//   6. 300 ms, then Escape
// While a key is held down, the Shift too, the module sends 57 AB 80 FF
// about every 65 ms: that is what the board's module did on 17 October 2026.
//
// It writes every byte it sends in wire.txt, with the time, in nanoseconds,
// when its stop bit ends: the judge in Python reads the frames from there.
`timescale 1ns/1ns
module ch9350 (
    input  wire go,         // 1: start
    output reg  tx   = 1,   // to our computer: 1 when nothing is sent
    output reg  done = 0,   // 1: everything was sent
    output reg  [3:0] phase = 0
);
    // A bit lasts BIT nanoseconds: 8,750 is 218.75 ticks of the test benches'
    // 40 nanoseconds, as long as a bit at 115,200 bits a second lasts with the
    // board's 25.2 MHz. +module_bit=8488 on the command line of vvp makes the
    // module 3 % fast, +module_bit=9013 3 % slow.
    integer BIT = 8750;
    parameter QUICK  = 0;
    parameter PAUSES = 0;
    parameter WIRE   = "wire.txt";
    initial begin
        if ($value$plusargs("module_bit=%d", BIT))
            $display("the keyboard's module: a bit lasts %0d ns", BIT);
    end

    localparam GAP = 2_000_000;     // 2 ms between two reports
    localparam LEFT_SHIFT  = 8'h02; // the modifier keys, one bit each
    localparam RIGHT_SHIFT = 8'h20;

    integer bytes   = 0;
    integer reports = 0;
    integer wire_file;
    initial wire_file = $fopen(WIRE, "w");

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
            $fwrite(wire_file, "%0t %02x\n", $time, value);
            $fflush(wire_file);
            bytes = bytes + 1;
        end
    endtask

    // A frame of three bytes: 57 AB and its kind.
    task short_frame(input [7:0] kind);
        begin
            send_byte(8'h57);
            send_byte(8'hAB);
            send_byte(kind);
        end
    endtask

    // 57 AB 80 and its byte.
    task status(input [7:0] value);
        begin
            short_frame(8'h80);
            send_byte(value);
        end
    endtask

    // A report of the mouse: buttons, X, Y, wheel.
    task mouse(input [7:0] buttons, input [7:0] x, input [7:0] y, input [7:0] wheel);
        begin
            short_frame(8'h02);
            send_byte(buttons);
            send_byte(x);
            send_byte(y);
            send_byte(wheel);
            #(GAP);
        end
    endtask

    // What the keyboard holds down: the modifier keys, and up to six codes in
    // the order they went down. A key that comes up leaves its place, and the
    // ones after it move up. With more than six, the six places say 01.
    reg [7:0] modifiers = 0;
    reg [7:0] down [0:6];
    integer   held = 0;
    integer   copies = 2;           // how many times each report is sent
    integer   k0;
    initial for (k0 = 0; k0 < 7; k0 = k0 + 1) down[k0] = 0;

    // The report as it stands, sent copies times, GAP apart.
    task tell;
        integer t, k;
        begin
            for (t = 0; t < copies; t = t + 1) begin
                short_frame(8'h01);
                send_byte(modifiers);
                send_byte(8'h00);
                for (k = 0; k < 6; k = k + 1) send_byte(held > 6 ? 8'h01 : down[k]);
                reports = reports + 1;
                #(GAP);
            end
        end
    endtask

    task press(input [7:0] code);
        begin
            down[held] = code;
            held = held + 1;
            tell;
        end
    endtask

    task let_go(input [7:0] code);
        integer k, from;
        begin
            from = 7;
            for (k = 6; k >= 0; k = k - 1) if (down[k] == code) from = k;
            for (k = from; k < 6; k = k + 1) down[k] = down[k + 1];
            down[6] = 0;
            held = held - 1;
            tell;
        end
    endtask

    // Two keys that go down so close together that one report tells both.
    task press_two(input [7:0] first, input [7:0] second);
        begin
            down[held] = first;
            down[held + 1] = second;
            held = held + 2;
            tell;
        end
    endtask

    // A key pressed and let go, then a pause.
    task tap(input [7:0] code);
        begin
            press(code);
            let_go(code);
            #(GAP);
        end
    endtask

    // A key pressed with a Shift held down.
    task shifted(input [7:0] shift, input [7:0] code);
        begin
            modifiers = modifiers | shift;
            tell;
            tap(code);
            modifiers = modifiers & ~shift;
            tell;
        end
    endtask

    // Some text, as the keys of a US keyboard give it: small letters, digits,
    // dots and spaces.
    task text(input [8 * 16 - 1:0] what);
        integer k;
        reg [7:0] c;
        begin
            for (k = 15; k >= 0; k = k - 1) begin
                c = what[8 * k +: 8];
                if (c >= "a" && c <= "z") tap(8'h04 + c - "a");
                else if (c >= "1" && c <= "9") tap(8'h1E + c - "1");
                else if (c == "0") tap(8'h27);
                else if (c == ".") tap(8'h37);
                else if (c == " ") tap(8'h2C);
                else if (c != 0) $display("ch9350.v: no key for %c", c);
            end
        end
    endtask

    localparam RETURN = 8'h28, ESCAPE = 8'h29, BACKSPACE = 8'h2A, SEMICOLON = 8'h33;

    // While keys are held down: a frame of state, 57 AB 80 FF, every 65 ms,
    // times times.
    task hold(input integer times);
        integer t;
        begin
            for (t = 0; t < times; t = t + 1) begin
                #(65_000_000);
                status(8'hFF);
            end
        end
    endtask

    initial begin
        wait (go && !PAUSES);
        // 7 nanoseconds more, so that the wire never changes at the very moment
        // the clock ticks: which of the two would come first is up to the
        // simulator, and two simulators would not count the same.
        #7;

        phase = 1;
        short_frame(8'h86);
        status(8'hFF);
        short_frame(8'h89);
        status(8'hFF);
        #(GAP);

        phase = 2;
        copies = 3;                                 // c: three times down,
        press(8'h06);
        copies = 5;                                 // five times up
        let_go(8'h06);
        copies = 2;
        #(GAP);
        text("108.c10f");
        tap(RETURN);

        phase = 3;
        text("8000");
        shifted(LEFT_SHIFT, SEMICOLON);             // :
        text(" 15");
        tap(RETURN);

        if (!QUICK) begin
            phase = 4;
            text("0500");
            shifted(RIGHT_SHIFT, SEMICOLON);        // : with the other Shift
            tap(8'h2C);
            press(8'h04);                           // a down
            mouse(8'h00, 8'h05, 8'hFE, 8'h00);
            press(8'h05);                           // b down, a still down
            mouse(8'h00, 8'h57, 8'hAB, 8'h01);      // 57 AB 01 inside a mouse's frame
            let_go(8'h04);                         // a up
            let_go(8'h05);                         // b up
            #(GAP);
            press_two(8'h06, 8'h07);                // c and d, in the same report
            let_go(8'h07);                          // d up first
            let_go(8'h06);
            #(GAP);
            tap(RETURN);

            phase = 5;
            text("0500x");
            tap(BACKSPACE);
            tap(RETURN);

            phase = 6;
            tap(BACKSPACE);                         // the line is empty: nothing
            text("1234r");
            tap(ESCAPE);

            phase = 7;
            press(8'h04);                           // a
            press(8'h16);                           // s
            press(8'h07);                           // d
            press(8'h09);                           // f
            press(8'h0A);                           // g
            press(8'h0B);                           // h
            press(8'h0D);                           // j: one too many
            let_go(8'h0D);
            let_go(8'h04);
            let_go(8'h16);
            let_go(8'h07);
            let_go(8'h09);
            let_go(8'h0A);
            let_go(8'h0B);
            #(GAP);
            tap(ESCAPE);

            phase = 8;
            text("0400");
            shifted(LEFT_SHIFT, SEMICOLON);
            tap(8'h2C);
            press(8'h1E);                           // 1, held down: its report
            #(575_000_000 - 2 * GAP);               // went out twice, GAP apart
            let_go(8'h1E);                         // 575 ms after the first
            #(GAP);
            text(" 22");
            tap(RETURN);

            phase = 9;
            text("0600");
            shifted(LEFT_SHIFT, SEMICOLON);
            text("11 22 33 44 55 6");
            text("6 77 88 99 aa bb");
            text(" x");                             // x in the last column of the row
            tap(BACKSPACE);
            text("cc");
            press(BACKSPACE);                       // Backspace, held down: its report
            #(675_000_000 - 2 * GAP);               // went out twice, GAP apart
            let_go(BACKSPACE);                      // 675 ms after the first
            #(GAP);
            text("bb cc");
            tap(RETURN);
        end

        phase = 10;
        done = 1;
    end

    // The other story, with PAUSES at 1.
    localparam PAUSE = 300_000_000;     // 300 ms: the cursor shows after 250
    initial begin
        wait (go && PAUSES);
        #7;

        phase = 1;
        short_frame(8'h86);
        status(8'hFF);
        short_frame(8'h89);
        status(8'hFF);
        #(GAP);

        phase = 2;
        modifiers = LEFT_SHIFT;                     // Shift alone, held down:
        tell;                                       // the cursor blinks on
        hold(13);
        modifiers = 0;
        tell;
        tap(8'h06);                                 // c, while the cursor shows

        phase = 3;
        #(PAUSE);
        tap(BACKSPACE);

        phase = 4;
        #(PAUSE);
        text("8000");
        #(PAUSE);
        tap(RETURN);

        phase = 5;
        press(8'h27);                               // 0, held down
        hold(8);
        let_go(8'h27);

        phase = 6;
        #(PAUSE);
        tap(ESCAPE);

        phase = 10;
        done = 1;
    end
endmodule
