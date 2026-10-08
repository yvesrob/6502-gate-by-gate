// Chapter 3, test bench for counter.v: it counts, it wraps around after 63,
// it waits when enable is 0, and it goes back to zero on reset.
`timescale 1ns/1ns
module counter_tb;
    reg        clk    = 0;
    reg        reset  = 0;
    reg        enable = 0;
    wire [5:0] count;

    counter dut (
        .clk    (clk),
        .reset  (reset),
        .enable (enable),
        .count  (count)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer n;
    integer checked = 0;
    integer errors  = 0;

    // Let one tick go by, then compare count with the value we expect.
    task tick_and_check;
        input [5:0] expected;
        begin
            @(negedge clk);
            checked = checked + 1;
            if (count !== expected) begin
                errors = errors + 1;
                // Print the first ten mistakes, not all of them.
                if (errors <= 10) begin
                    $display("wrong: count is %0d, expected %0d", count, expected);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, counter_tb);

        // enable is 0: three ticks go by and nothing happens.
        tick_and_check(0);
        tick_and_check(0);
        tick_and_check(0);
        $display("enable = 0, three ticks: count = %0d", count);

        // enable is 1: one more at every tick, all the way up to 63.
        enable = 1;
        for (n = 1; n <= 63; n = n + 1) begin
            tick_and_check(n);
        end
        $display("enable = 1, 63 ticks:    count = %0d", count);

        // One more tick. Six bits cannot hold 64: the counter starts again at 0.
        tick_and_check(0);
        $display("one more tick:           count = %0d", count);

        // Five more ticks, then enable goes back to 0: the count stays where it is.
        for (n = 1; n <= 5; n = n + 1) begin
            tick_and_check(n);
        end
        enable = 0;
        tick_and_check(5);
        tick_and_check(5);
        $display("enable = 0 again:        count = %0d", count);

        // reset wins over enable.
        enable = 1;
        reset  = 1;
        tick_and_check(0);
        $display("reset = 1:               count = %0d", count);

        // And when reset is released, the counting starts again from 0.
        reset = 0;
        tick_and_check(1);
        tick_and_check(2);
        $display("reset = 0, two ticks:    count = %0d", count);

        if (errors == 0) begin
            $display("PASS: counter, %0d checks", checked);
            $finish;
        end else begin
            $display("FAIL: counter, %0d wrong value(s) out of %0d", errors, checked);
            $fatal;
        end
    end
endmodule
