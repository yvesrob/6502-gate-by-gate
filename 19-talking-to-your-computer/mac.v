// Chapter 19: the Mac, for the test benches. It does what tools/send.py does.
// It reads the text that tools/send.py sends, written by tools/send.py --show
// into build/maze.txt, and sends it on rx, bit by bit, a line at a time: up to
// and including a line feed, or to the end of the text. After each line it
// waits until every character of it has come back on tx, then checks that
// they are the same, and only then sends the next line. When all of it has
// come back, done is 1. Then it goes on listening: what the program says
// comes after the echo, and the Mac writes it, line by line.
//
// Its bits last 8,746 ns. With the test benches' tick of 40 ns, that is
// 218.65 ticks: the speed at which the board's USB chip sent bytes to ours,
// measured on the board, 11,525 bytes a second. It hears ours at that speed
// too.
`timescale 1ns/1ns
module mac (
    input  wire go,         // 1: start sending
    input  wire tx,         // from our computer
    output reg  rx   = 1,   // to our computer: 1 when nothing is sent
    output reg  done = 0    // 1: everything was sent and came back
);
    parameter FILE = "maze.txt";
    parameter BIT  = 8746;          // nanoseconds

    reg [7:0] text  [0:8191];       // what it sends
    integer   length = 0;
    reg [7:0] heard [0:8191];       // what it hears, in order: the echo, then the rest
    integer   count  = 0;
    integer   wrong  = 0;           // characters that came back different
    integer   lines  = 0;           // lines sent and come back
    integer   late   = 0;           // lines that did not all come back within 50 ms
    integer   broken = 0;           // bytes heard without their stop bit

    // The text, byte after byte.
    integer f;
    integer c;
    initial begin
        f = $fopen(FILE, "rb");
        if (f == 0) begin
            $display("FAIL: the Mac cannot read %0s", FILE);
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

    // Listening: a falling edge is a start bit; then the middle of each bit.
    reg [7:0] byte_heard;
    integer   k;
    integer   said_from = -1;       // where the line the program is saying began
    initial begin
        forever begin
            @(negedge tx);
            #(BIT / 2);
            if (tx == 0) begin
                for (k = 0; k < 8; k = k + 1) begin
                    #(BIT);
                    byte_heard[k] = tx;
                end
                #(BIT);                 // the middle of the stop bit: it must be 1
                if (tx !== 1) broken = broken + 1;
                heard[count] = byte_heard;
                count = count + 1;
                if (done) begin
                    // After the echo: what the program says, a line at a time.
                    if (said_from < 0) said_from = count - 1;
                    if (byte_heard == 10) begin
                        $write("the Mac hears: ");
                        for (k = said_from; k < count; k = k + 1) begin
                            if (heard[k] != 13 && heard[k] != 10) $write("%c", heard[k]);
                        end
                        $display("");
                        said_from = count;
                    end
                end
            end
        end
    end

    // Sending one byte: the start bit, the eight bits from the lowest, the stop bit.
    task send_byte(input [7:0] value);
        integer b;
        begin
            rx = 0;
            #(BIT);
            for (b = 0; b < 8; b = b + 1) begin
                rx = value[b];
                #(BIT);
            end
            rx = 1;
            #(BIT);
        end
    endtask

    integer i;
    integer first;
    integer waited;
    integer j;
    initial begin
        wait (go);
        i = 0;
        while (i < length) begin
            first = i;
            send_byte(text[i]);
            i = i + 1;
            while (i < length && text[i - 1] != 10) begin
                send_byte(text[i]);
                i = i + 1;
            end
            waited = 0;
            while (count < i && waited < 50_000_000) begin
                #10000;
                waited = waited + 10000;
            end
            if (count < i) late = late + 1;
            for (j = first; j < i; j = j + 1) begin
                if (j >= count || heard[j] !== text[j]) wrong = wrong + 1;
            end
            lines = lines + 1;
        end
        done = 1;
    end
endmodule
