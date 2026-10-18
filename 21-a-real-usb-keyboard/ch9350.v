// Chapter 21: the keyboard's module, for the test benches. It plays the
// CH9350 with a keyboard plugged in: it sends frames on its wire, tx, as the
// chip does on its pin TXD, at 115,200 bits a second, and a person types.
// The frames are those of the chip's datasheet (version 2.3, the frames of
// state 2):
//   57 AB 01 and the keyboard's 8 bytes    (57 AB 01 00 00 2C 00 00 00 00 00:
//                                           the space bar is down)
//   57 AB 02 and the mouse's 4 bytes
//   57 AB 80 and 1 byte
// and those that the chip was seen to send by people who listened to it:
// 57 AB 86, 57 AB 89 and 57 AB 80 FF when it starts, each report three to five
// times over, 57 AB 80 30 between them.
//
// What happens, in order (one phase after the other, phase counts them):
//   1. the chip starts: 57 AB 86, 57 AB 80 FF, 57 AB 89, 57 AB 80 FF
//   2. Q, W, then E, pressed and let go, one at a time; each report comes
//      three times when a key goes down, five times when it comes up
//      then a pause of 10 milliseconds
//   3. the left Shift held, A pressed and let go, Shift let go
//   4. Q held, then W with it; Q let go, then W
//   5. a mouse moves: seven frames, one after the other; one of them carries
//      57, AB and 01, which must not be taken for a frame of the keyboard
//   6. six keys held, A S D F G H, then a seventh: the keyboard says it
//      cannot tell, 01 in the six places; then all let go
//   7. bytes that begin no frame: AB, 01, 57, 12, 57; then the space bar,
//      pressed and let go
//   8. twelve reports in a row, two milliseconds apart: 1 to 6 pressed and let
//      go, faster than anyone types. Their lines make the screen scroll, and
//      while it scrolls their bytes wait in the queue
// Between the frames of a phase it waits 4 milliseconds, except where it says
// otherwise. When everything is sent, done is 1. With QUICK at 1, only phases
// 1, 2, 5 and 7 happen: board_tb asks for that, to be shorter.
//
// It writes down every report of the keyboard it sends, in order, in sent,
// and, in skipped, how many bytes that begin no frame it had sent before
// each: the test benches work out from them the lines they expect.
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
    parameter QUICK = 0;
    initial begin
        if ($value$plusargs("module_bit=%d", BIT))
            $display("the keyboard's module: a bit lasts %0d ns", BIT);
    end

    localparam GAP = 4_000_000;     // 4 ms between two frames

    // What it sent: the reports of the keyboard, eight bytes each, the byte
    // that comes first on the left; and how many bytes in all.
    reg [63:0] sent [0:255];
    integer    skipped [0:255];     // for each report, how many bytes that begin no frame came before it
    integer    reports = 0;
    integer    bytes   = 0;
    integer    frames  = 0;         // every frame, the keyboard's and the others
    integer    junk    = 0;         // bytes sent that begin no frame
    reg [7:0]  on_the_wire [0:4095];    // every byte sent, in order

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
            on_the_wire[bytes] = value;
            bytes = bytes + 1;
        end
    endtask

    // A frame of three bytes: 57 AB and its kind.
    task short_frame(input [7:0] kind);
        begin
            send_byte(8'h57);
            send_byte(8'hAB);
            send_byte(kind);
            frames = frames + 1;
        end
    endtask

    // 57 AB 80 and its byte.
    task status(input [7:0] value);
        begin
            short_frame(8'h80);
            send_byte(value);
        end
    endtask

    // A report of the keyboard, the modifier keys first, sent times times,
    // pause nanoseconds apart.
    task keyboard(input [63:0] report, input integer times, input integer pause);
        integer t, k;
        begin
            for (t = 0; t < times; t = t + 1) begin
                short_frame(8'h01);
                for (k = 7; k >= 0; k = k - 1) send_byte(report[8 * k +: 8]);
                sent[reports] = report;
                skipped[reports] = junk;
                reports = reports + 1;
                #(pause);
            end
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
        end
    endtask

    // A key goes down and comes up: three reports, then five.
    task key(input [7:0] code);
        begin
            keyboard({8'h00, 8'h00, code, 40'h0}, 3, GAP);
            keyboard(64'h0, 5, GAP);
        end
    endtask

    initial begin
        wait (go);
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
        keyboard(64'h0000_1400_0000_0000, 2, GAP);
        status(8'h30);                                  // between two of them
        keyboard(64'h0000_1400_0000_0000, 1, GAP);
        keyboard(64'h0, 5, GAP);
        key(8'h1A);                                     // W
        keyboard(64'h0000_0800_0000_0000, 2, 0);        // E: these two and the next, back to back
        keyboard(64'h0000_0800_0000_0000, 1, GAP);
        keyboard(64'h0, 5, GAP);
        #(10_000_000);

        if (!QUICK) begin
            phase = 3;
            keyboard(64'h0200_0000_0000_0000, 3, GAP);  // the left Shift
            keyboard(64'h0200_0400_0000_0000, 3, GAP);  // and A
            keyboard(64'h0200_0000_0000_0000, 5, GAP);
            keyboard(64'h0, 5, GAP);

            phase = 4;
            keyboard(64'h0000_1400_0000_0000, 3, GAP);  // Q
            keyboard(64'h0000_141A_0000_0000, 3, GAP);  // and W
            keyboard(64'h0000_1A00_0000_0000, 5, GAP);  // Q let go
            keyboard(64'h0, 5, GAP);
        end

        phase = 5;
        mouse(8'h00, 8'h05, 8'hFE, 8'h00);
        mouse(8'h00, 8'h57, 8'hAB, 8'h01);              // 57 AB 01 inside a mouse's frame
        mouse(8'h00, 8'h07, 8'h00, 8'h00);
        mouse(8'h01, 8'h00, 8'h00, 8'h00);
        mouse(8'h00, 8'hF9, 8'h03, 8'h00);
        mouse(8'h00, 8'h01, 8'h57, 8'hAB);
        mouse(8'h00, 8'h00, 8'h00, 8'hFF);
        #(GAP);

        if (!QUICK) begin
            phase = 6;
            keyboard(64'h0000_0416_0709_0A0B, 3, GAP);  // A S D F G H
            keyboard(64'h0000_0101_0101_0101, 3, GAP);  // and J: one key too many
            keyboard(64'h0, 5, GAP);
        end

        phase = 7;
        send_byte(8'hAB);
        send_byte(8'h01);
        send_byte(8'h57);
        send_byte(8'h12);
        send_byte(8'h57);
        junk = junk + 5;
        #(GAP);
        key(8'h2C);                                     // the space bar

        if (!QUICK) begin
            phase = 8;
            keyboard(64'h0000_1E00_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
            keyboard(64'h0000_1F00_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
            keyboard(64'h0000_2000_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
            keyboard(64'h0000_2100_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
            keyboard(64'h0000_2200_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
            keyboard(64'h0000_2300_0000_0000, 1, 2_000_000);
            keyboard(64'h0,                   1, 2_000_000);
        end

        phase = 9;
        done = 1;
    end
endmodule
