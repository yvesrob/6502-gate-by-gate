// Chapter 9: the ALU, the arithmetic and logic unit. It is the part of the
// processor that computes: it adds, subtracts, compares, shifts, and combines
// bits. Gates only: no clock, no memory. Two bytes and a carry come in, a
// byte and four flags come out, and operation says what happens in between.
module alu (
    input  wire [3:0] operation,    // what to do: one of the names of alu_operations.vh
    input  wire [7:0] a,            // the value we work on
    input  wire [7:0] b,            // the value we combine it with, when there are two
    input  wire       carry_in,
    output wire [7:0] result,
    output wire       carry_out,    // ninth bit of a sum, or the bit a shift pushes out
    output wire       overflow,     // the sum does not fit in a signed byte
    output wire       negative,     // bit 7 of the result
    output wire       zero          // the result is zero
);
    `include "alu_operations.vh"

    // One adder does five jobs. What changes from one job to the next is its
    // second number, and its first carry: the one that enters column 0.
    //   ADD        a + b    + carry_in
    //   SUBTRACT   a + ~b   + carry_in     (inverting b and adding 1 subtracts b)
    //   COMPARE    a + ~b   + 1
    //   INCREMENT  a + 0    + 1
    //   DECREMENT  a + 255  + 0            (adding 255 on a byte takes 1 away)
    wire subtracting;
    assign subtracting = (operation == ALU_SUBTRACT) | (operation == ALU_COMPARE);

    wire [7:0] second;
    assign second = (operation == ALU_ADD)       ? b      :
                    subtracting                  ? ~b     :
                    (operation == ALU_DECREMENT) ? 8'd255 : 8'd0;

    wire first_carry;
    assign first_carry = (operation == ALU_ADD)       ? carry_in :
                         (operation == ALU_SUBTRACT)  ? carry_in :
                         (operation == ALU_COMPARE)   ? 1'b1     :
                         (operation == ALU_INCREMENT) ? 1'b1     : 1'b0;

    // Nine bits: the eight of the sum, and the carry that comes out.
    wire [8:0] sum;
    assign sum = a + second + first_carry;

    // The result: the first test that matches wins. An operation that is not
    // named here is one of the five jobs of the adder.
    assign result = (operation == ALU_PASS)         ? a                  :
                    (operation == ALU_AND)          ? a & b              :
                    (operation == ALU_OR)           ? a | b              :
                    (operation == ALU_XOR)          ? a ^ b              :
                    (operation == ALU_SHIFT_LEFT)   ? {a[6:0], 1'b0}     :
                    (operation == ALU_ROTATE_LEFT)  ? {a[6:0], carry_in} :
                    (operation == ALU_SHIFT_RIGHT)  ? {1'b0, a[7:1]}     :
                    (operation == ALU_ROTATE_RIGHT) ? {carry_in, a[7:1]} :
                                                      sum[7:0];

    // The carry: a shift to the left pushes bit 7 out, a shift to the right
    // pushes bit 0 out, and the adder gives its ninth bit.
    assign carry_out = (operation == ALU_SHIFT_LEFT)   ? a[7] :
                       (operation == ALU_ROTATE_LEFT)  ? a[7] :
                       (operation == ALU_SHIFT_RIGHT)  ? a[0] :
                       (operation == ALU_ROTATE_RIGHT) ? a[0] :
                                                         sum[8];

    // The overflow: the adder was given two numbers of the same sign, and
    // the sum came out with the other sign.
    assign overflow = (a[7] == second[7]) & (sum[7] != a[7]);

    // Two flags that only look at the result.
    assign negative = result[7];
    assign zero     = (result == 0);
endmodule
