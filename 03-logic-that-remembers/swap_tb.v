// Chapter 3, test bench for swap.v: a and b must trade places at every tick.
`timescale 1ns/1ns
module swap_tb;
    reg  clk = 0;
    wire a;
    wire b;

    swap dut (
        .clk (clk),
        .a   (a),
        .b   (b)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer errors = 0;

    task check;
        input want_a;
        input want_b;
        begin
            $display("%2d ns   a = %b   b = %b", $time, a, b);
            if (a !== want_a || b !== want_b) begin
                $display("        ^ wrong, expected a = %b   b = %b", want_a, want_b);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("swap_tb.vcd");
        $dumpvars(0, swap_tb);

        #1 check(0, 1);                 // before the first tick

        // We look on the falling edge of the clock: half-way between two ticks,
        // when everything has settled.
        @(negedge clk) check(1, 0);     // one tick later: traded
        @(negedge clk) check(0, 1);     // and back
        @(negedge clk) check(1, 0);
        @(negedge clk) check(0, 1);

        if (errors == 0) begin
            $display("PASS: swap, 5 checks");
            $finish;
        end else begin
            $display("FAIL: swap, %0d wrong value(s) out of 5", errors);
            $fatal;
        end
    end
endmodule
