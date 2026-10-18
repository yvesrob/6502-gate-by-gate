// Chapter 22 uses the serial_tb from chapter 19. This file is a copy of it, unchanged.
// Chapter 19, test bench for the serial link: the transmitter and the
// receiver alone, bit by bit.
//   1. The transmitter sends the 256 bytes. The test bench watches the wire at
//      every tick: each byte must be a start bit at 0, its eight bits, the
//      lowest first, and a stop bit at 1, each exactly 219 ticks long, and busy
//      must be 1 for exactly the 2,190 ticks of the ten bits. A byte sent
//      while busy is 1 must change nothing.
//   2. The receiver hears the 256 bytes from a Mac whose bits last 218.75
//      ticks (115,200 bits a second at 25.2 MHz), back to back; then from a
//      Mac 3 % slow and from one 3 % fast.
//   3. A dip shorter than half a bit is not a start bit; a byte whose stop bit
//      is 0 is thrown away, and the byte after it still arrives.
//   4. The transmitter's wire goes straight into the receiver: 256 bytes.
`timescale 1ns/1ps
module serial_tb;
    reg clk = 0;
    always #20 clk = ~clk;          // one tick every 40 ns

    // The transmitter, watched.
    reg        send = 0;
    reg  [7:0] data = 0;
    wire       tx;
    wire       busy;

    transmitter sender (
        .clk  (clk),
        .send (send),
        .data (data),
        .tx   (tx),
        .busy (busy)
    );

    // The receiver, fed by the test bench, or by the transmitter (part 4).
    reg        mac  = 1;            // the wire from the test bench's Mac
    reg        loop = 0;            // 1: the transmitter's wire instead
    wire       rx;
    wire [7:0] received;
    wire       arrived;
    assign rx = loop ? tx : mac;

    receiver listener (
        .clk     (clk),
        .rx      (rx),
        .data    (received),
        .arrived (arrived)
    );

    integer errors = 0;

    // Every byte the receiver gives, in order.
    reg [7:0] heard [0:2047];
    integer   count = 0;
    always @(posedge clk) begin
        if (arrived) begin
            heard[count] = received;
            count = count + 1;
        end
    end

    // The Mac sends a byte, each bit lasting bit_ns nanoseconds.
    task mac_sends(input [7:0] value, input real bit_ns, input stop);
        integer k;
        begin
            mac = 0;
            #(bit_ns);
            for (k = 0; k < 8; k = k + 1) begin
                mac = value[k];
                #(bit_ns);
            end
            mac = stop;
            #(bit_ns);
            mac = 1;
        end
    endtask

    // Part 1: the transmitter sends value; the test bench looks at the wire
    // at every tick, between two rising edges.
    task watch_a_byte(input [7:0] value);
        integer k, t, busy_ticks;
        reg [9:0] expected;
        begin
            expected = {1'b1, value, 1'b0};     // stop, the byte, start: the start goes first
            @(negedge clk);
            data = value;
            send = 1;
            @(negedge clk);
            send = 0;
            data = ~value;                      // the byte is taken: changing data changes nothing
            busy_ticks = 0;
            for (k = 0; k < 10; k = k + 1) begin
                for (t = 0; t < 219; t = t + 1) begin
                    if (tx !== expected[k]) begin
                        if (errors < 10) $display("byte %h: bit %0d, tick %0d: the wire is %b", value, k, t, tx);
                        errors = errors + 1;
                    end
                    if (busy) busy_ticks = busy_ticks + 1;
                    send = (k == 4 && t == 100);    // a byte sent while busy: it must be ignored
                    @(negedge clk);
                end
            end
            if (busy_ticks != 2190 || busy !== 0 || tx !== 1) begin
                $display("byte %h: busy for %0d ticks, then busy %b, wire %b", value, busy_ticks, busy, tx);
                errors = errors + 1;
            end
        end
    endtask

    // Part 2: the Mac sends the 256 bytes; the receiver must give them all, in order.
    task hear_all(input real bit_ns, input [8*24:1] what);
        integer v, start, right;
        begin
            start = count;
            for (v = 0; v < 256; v = v + 1) mac_sends(v[7:0], bit_ns, 1);
            #(bit_ns * 2);
            right = 0;
            for (v = 0; v < 256; v = v + 1) begin
                if (start + v < count && heard[start + v] === v[7:0]) right = right + 1;
            end
            $display("2. %0s: %0d bytes heard, %0d right of 256", what, count - start, right);
            if (count - start != 256 || right != 256) errors = errors + 1;
        end
    endtask

    integer v, start, right;
    initial begin
        // Part 1.
        for (v = 0; v < 256; v = v + 1) watch_a_byte(v[7:0]);
        $display("1. the transmitter: 256 bytes, each bit 219 ticks on the wire, busy 2190 ticks; %0d wrong", errors);

        // Part 2.
        #1000;
        hear_all(8750.0, "the Mac at 115,200");
        hear_all(8750.0 * 1.03, "a Mac 3 % slow");
        hear_all(8750.0 / 1.03, "a Mac 3 % fast");

        // Part 3. A dip of 100 ticks, then nothing: no byte. Then a byte whose
        // stop bit is 0, then 5A: only 5A.
        start = count;
        mac = 0; #4000; mac = 1;
        #(8750 * 12);
        mac_sends(8'hA5, 8750.0, 0);
        #(8750 * 2);
        mac_sends(8'h5A, 8750.0, 1);
        #(8750 * 2);
        $display("3. a dip of 100 ticks, a byte without its stop bit, then 5A: %0d byte(s) heard, the first %h",
                 count - start, heard[start]);
        if (count - start != 1 || heard[start] !== 8'h5A) errors = errors + 1;

        // Part 4. The transmitter into the receiver.
        loop  = 1;
        start = count;
        for (v = 0; v < 256; v = v + 1) begin
            @(negedge clk);
            data = v;
            send = 1;
            @(negedge clk);
            send = 0;
            wait (busy == 0);
        end
        #(8750 * 2);
        right = 0;
        for (v = 0; v < 256; v = v + 1) if (heard[start + v] === v[7:0]) right = right + 1;
        $display("4. the transmitter into the receiver: %0d bytes heard, %0d right of 256", count - start, right);
        if (count - start != 256 || right != 256) errors = errors + 1;

        if (errors == 0) $display("PASS: serial, 256 bytes out bit by bit, 1,024 heard right, the dip and the byte without its stop bit thrown away");
        else             $display("FAIL: serial, %0d wrong", errors);
        $finish;
    end

    // A time limit: everything above takes about 0.14 s of simulated time.
    initial begin
        #400000000;
        $display("FAIL: serial, still running after 0.4 s");
        $finish;
    end
endmodule
