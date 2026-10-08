// Chapter 3, test bench for register.v: it takes a value when load is 1,
// and keeps it for as long as load is 0.
`timescale 1ns/1ns
module register_tb;
    reg        clk  = 0;
    reg        load = 0;
    reg  [7:0] d    = 0;
    wire [7:0] q;

    register dut (
        .clk  (clk),
        .load (load),
        .d    (d),
        .q    (q)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer errors = 0;

    // Let one tick go by, then compare q with the value we expect.
    // We stop on the falling edge: half-way between two ticks.
    task tick_and_check;
        input [7:0] expected;
        begin
            @(negedge clk);
            $display("load = %b   d = %3d   q = %3d", load, d, q);
            if (q !== expected) begin
                $display("                       ^ wrong, expected %0d", expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("register_tb.vcd");
        $dumpvars(0, register_tb);

        load = 0; d = 42;   tick_and_check(0);      // load is 0: q stays at 0
        load = 1;           tick_and_check(42);     // load is 1: q takes 42
        load = 0; d = 99;   tick_and_check(42);     // d changes, q keeps 42
                  d = 7;    tick_and_check(42);     // and keeps it
        load = 1;           tick_and_check(7);      // load again: q takes 7
                  d = 255;  tick_and_check(255);    // load still 1: q follows d
        load = 0; d = 0;    tick_and_check(255);    // and q keeps 255

        if (errors == 0) begin
            $display("PASS: register, 7 checks");
            $finish;
        end else begin
            $display("FAIL: register, %0d wrong value(s) out of 7", errors);
            $fatal;
        end
    end
endmodule
