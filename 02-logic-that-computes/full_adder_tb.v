// Chapter 2, test bench for full_adder.v: the eight additions of three bits.
`timescale 1ns/1ns
module full_adder_tb;
    reg  a;
    reg  b;
    reg  carry_in;
    wire sum;
    wire carry_out;

    full_adder dut (
        .a         (a),
        .b         (b),
        .carry_in  (carry_in),
        .sum       (sum),
        .carry_out (carry_out)
    );

    integer   i;
    reg [1:0] expected;     // the answer, as a two-bit number
    integer   errors = 0;

    initial begin
        $dumpfile("full_adder_tb.vcd");
        $dumpvars(0, full_adder_tb);

        $display("a + b + carry_in = carry_out sum");

        // i counts from 0 to 7. Its three bits give us the eight possible inputs.
        for (i = 0; i < 8; i = i + 1) begin
            a        = i[2];
            b        = i[1];
            carry_in = i[0];
            // This time we do not write the answers by hand:
            // we let Verilog's own + work them out, and we compare.
            expected = a + b + carry_in;
            #10;
            $display("%b + %b + %b = %b%b", a, b, carry_in, carry_out, sum);
            if ({carry_out, sum} !== expected) begin
                $display("            ^ wrong, expected %b", expected);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("PASS: full_adder, 8 additions checked");
            $finish;
        end else begin
            $display("FAIL: full_adder, %0d wrong addition(s) out of 8", errors);
            $fatal;
        end
    end
endmodule
