// Chapter 2, test bench for half_adder.v: the four additions of two bits.
`timescale 1ns/1ns
module half_adder_tb;
    reg  a;
    reg  b;
    wire sum;
    wire carry;

    half_adder dut (
        .a     (a),
        .b     (b),
        .sum   (sum),
        .carry (carry)
    );

    integer errors = 0;

    // Add two bits, print the addition, and compare with the answer we expect.
    task check;
        input       in_a;
        input       in_b;
        input [1:0] expected;   // the answer, as a two-bit number
        begin
            a = in_a;
            b = in_b;
            #10;
            $display("%b + %b = %b%b", a, b, carry, sum);
            // carry and sum, side by side, make a two-bit number.
            if ({carry, sum} !== expected) begin
                $display("        ^ wrong, expected %b", expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("half_adder_tb.vcd");
        $dumpvars(0, half_adder_tb);

        check(0, 0, 2'b00);
        check(0, 1, 2'b01);
        check(1, 0, 2'b01);
        check(1, 1, 2'b10);     // one plus one is two, and two is written 10

        if (errors == 0) begin
            $display("PASS: half_adder, 4 additions checked");
            $finish;
        end else begin
            $display("FAIL: half_adder, %0d wrong addition(s) out of 4", errors);
            $fatal;
        end
    end
endmodule
