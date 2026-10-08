// Chapter 3, test bench for flipflop.v: d moves whenever it likes,
// q only moves on a tick of the clock.
`timescale 1ns/1ns
module flipflop_tb;
    reg  clk = 0;
    reg  d   = 0;
    wire q;

    flipflop dut (
        .clk (clk),
        .d   (d),
        .q   (q)
    );

    // The clock of the test bench. It flips every 5 ns, so one period lasts
    // 10 ns, and the ticks (the rising edges) fall at 5, 15, 25, 35 ns...
    always #5 clk = ~clk;

    integer errors = 0;

    // Print the time, d and q, and compare q with the value we expect.
    task check;
        input expected;
        begin
            $display("%0d ns   d = %b   q = %b", $time, d, q);
            if (q !== expected) begin
                $display("                  ^ wrong, expected %b", expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("flipflop_tb.vcd");
        $dumpvars(0, flipflop_tb);

        #7  d = 1;      //  7 ns: d goes up, just after the tick at 5...
        #6  check(0);   // 13 ns: ...and q has not moved. It waits for the clock.
        #4  check(1);   // 17 ns: the tick at 15 has passed, q has taken d.
        #1  d = 0;      // 18 ns: d drops...
        #4  d = 1;      // 22 ns: ...and comes back before the next tick.
        #1  check(1);   // 23 ns: q never noticed.
        #4  check(1);   // 27 ns: at the tick at 25, d was 1 again. q stays at 1.
        #1  d = 0;      // 28 ns: d drops for good.
        #4  check(1);   // 32 ns: still 1, the next tick has not come yet.
        #5  check(0);   // 37 ns: the tick at 35 has passed, q has followed.

        if (errors == 0) begin
            $display("PASS: flipflop, 6 checks");
            $finish;
        end else begin
            $display("FAIL: flipflop, %0d wrong value(s) out of 6", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
