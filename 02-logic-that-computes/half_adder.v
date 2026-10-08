// Chapter 2: the half adder. Two gates that add two bits.
module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    // 0 + 0 = 00    0 + 1 = 01    1 + 0 = 01    1 + 1 = 10
    // The right-hand digit of the answer is sum, the left-hand one is carry.
    assign sum   = a ^ b;   // 1 when exactly one of the two bits is 1
    assign carry = a & b;   // 1 when both are 1: one to carry over
endmodule
