// Chapter 3, test bench for scanner.v: the light must go up, turn around,
// come back down, turn around again, and wait when step is 0.
`timescale 1ns/1ns
module scanner_tb;
    reg        clk  = 0;
    reg        step = 0;
    wire [5:0] light;

    scanner dut (
        .clk   (clk),
        .step  (step),
        .light (light)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer checked = 0;
    integer errors  = 0;

    // Let one tick go by, print the six lights, and compare with what we expect.
    task tick_and_check;
        input [5:0] expected;
        begin
            @(negedge clk);
            $display("step = %b   %b", step, light);
            checked = checked + 1;
            if (light !== expected) begin
                $display("           ^ wrong, expected %b", expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("scanner_tb.vcd");
        $dumpvars(0, scanner_tb);

        // step is 0: the light waits where it starts.
        tick_and_check(6'b000001);
        tick_and_check(6'b000001);

        // step is 1: one move at every tick.
        step = 1;
        tick_and_check(6'b000010);
        tick_and_check(6'b000100);
        tick_and_check(6'b001000);
        tick_and_check(6'b010000);
        tick_and_check(6'b100000);      // the top
        tick_and_check(6'b010000);      // and back
        tick_and_check(6'b001000);
        tick_and_check(6'b000100);
        tick_and_check(6'b000010);
        tick_and_check(6'b000001);      // the bottom
        tick_and_check(6'b000010);      // and up again
        tick_and_check(6'b000100);

        // step back to 0: the light stops where it is.
        step = 0;
        tick_and_check(6'b000100);
        tick_and_check(6'b000100);

        if (errors == 0) begin
            $display("PASS: scanner, %0d checks", checked);
            $finish;
        end else begin
            $display("FAIL: scanner, %0d wrong value(s) out of %0d", errors, checked);
            $fatal;
        end
    end
endmodule
