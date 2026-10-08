// Chapter 2, test bench for adder8.v: a few additions we can read,
// then every possible addition, all 131,072 of them.
`timescale 1ns/1ns
module adder8_tb;
    reg  [7:0] a;
    reg  [7:0] b;
    reg        carry_in;
    wire [7:0] sum;
    wire       carry_out;

    adder8 dut (
        .a         (a),
        .b         (b),
        .carry_in  (carry_in),
        .sum       (sum),
        .carry_out (carry_out)
    );

    // carry_out and the eight bits of sum, side by side: a nine-bit number.
    wire [8:0] result;
    assign result = {carry_out, sum};

    integer first;
    integer second;
    integer carry;
    integer checked = 0;
    integer errors  = 0;

    // Do one addition and print it in decimal.
    task show;
        input [7:0] in_a;
        input [7:0] in_b;
        begin
            a        = in_a;
            b        = in_b;
            carry_in = 0;
            #10;
            $display("%3d + %3d = %3d", a, b, result);
        end
    endtask

    initial begin
        $dumpfile("adder8_tb.vcd");
        $dumpvars(0, adder8_tb);

        // A few additions to look at, here and in the waveform.
        show(  1,   1);
        show( 23,  19);
        show(200,  55);
        show(255,   1);     // the answer needs a ninth bit: carry_out

        // Nobody wants to scroll through 131,072 additions:
        // the waveform stops here, the test goes on.
        $dumpoff;

        // Now all of them: 256 values for a, 256 for b, and carry_in at 0 or 1.
        // We compare each answer with what Verilog's own + gives.
        for (first = 0; first < 256; first = first + 1) begin
            for (second = 0; second < 256; second = second + 1) begin
                for (carry = 0; carry < 2; carry = carry + 1) begin
                    a        = first;
                    b        = second;
                    carry_in = carry;
                    #10;
                    checked = checked + 1;
                    if (result !== first + second + carry) begin
                        errors = errors + 1;
                        // Print the first ten mistakes, not thousands of them.
                        if (errors <= 10) begin
                            $display("wrong: %0d + %0d + %0d gave %0d",
                                     first, second, carry, result);
                        end
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("PASS: adder8, %0d additions checked", checked);
            $finish;
        end else begin
            $display("FAIL: adder8, %0d wrong addition(s) out of %0d", errors, checked);
            $fatal;
        end
    end
endmodule
