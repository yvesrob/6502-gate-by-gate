// Chapter 2: the eight-bit adder. Eight full adders in a chain,
// one per column, each passing its carry to the next.
module adder8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       carry_in,
    output wire [7:0] sum,
    output wire       carry_out
);
    // carry[1] goes from column 0 to column 1, carry[2] from column 1
    // to column 2, and so on up to carry[7].
    wire [7:1] carry;

    // Column 0 is the right-hand one, as when we add on paper.
    full_adder column0 (.a(a[0]), .b(b[0]), .carry_in(carry_in), .sum(sum[0]), .carry_out(carry[1]));
    full_adder column1 (.a(a[1]), .b(b[1]), .carry_in(carry[1]), .sum(sum[1]), .carry_out(carry[2]));
    full_adder column2 (.a(a[2]), .b(b[2]), .carry_in(carry[2]), .sum(sum[2]), .carry_out(carry[3]));
    full_adder column3 (.a(a[3]), .b(b[3]), .carry_in(carry[3]), .sum(sum[3]), .carry_out(carry[4]));
    full_adder column4 (.a(a[4]), .b(b[4]), .carry_in(carry[4]), .sum(sum[4]), .carry_out(carry[5]));
    full_adder column5 (.a(a[5]), .b(b[5]), .carry_in(carry[5]), .sum(sum[5]), .carry_out(carry[6]));
    full_adder column6 (.a(a[6]), .b(b[6]), .carry_in(carry[6]), .sum(sum[6]), .carry_out(carry[7]));
    full_adder column7 (.a(a[7]), .b(b[7]), .carry_in(carry[7]), .sum(sum[7]), .carry_out(carry_out));
endmodule
