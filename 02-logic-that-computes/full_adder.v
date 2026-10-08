// Chapter 2: the full adder. It adds three bits: a, b,
// and the carry that comes from the column on its right.
module full_adder (
    input  wire a,
    input  wire b,
    input  wire carry_in,
    output wire sum,
    output wire carry_out
);
    wire sum_ab;        // a + b, before the incoming carry is added
    wire carry_ab;      // the carry of a + b
    wire carry_extra;   // the carry of adding carry_in to that

    // Two half adders in a row: first a + b, then the result + carry_in.
    half_adder first (
        .a     (a),
        .b     (b),
        .sum   (sum_ab),
        .carry (carry_ab)
    );

    half_adder second (
        .a     (sum_ab),
        .b     (carry_in),
        .sum   (sum),
        .carry (carry_extra)
    );

    // There is a carry to pass on if either half adder produced one.
    assign carry_out = carry_ab | carry_extra;
endmodule
