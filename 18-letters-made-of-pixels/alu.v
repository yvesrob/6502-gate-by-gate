// Chapter 18 uses the alu from chapter 12. This file is a copy of it, unchanged.
// Chapter 12: the ALU from chapter 9, with one more input, decimal. When it
// is 1, ADD and SUBTRACT count in decimal, two digits to a byte. The other
// eleven operations do not look at it.
//
// Chapter 9: the ALU, the arithmetic and logic unit. It is the part of the
// processor that computes: it adds, subtracts, compares, shifts, and combines
// bits. Gates only: no clock, no memory. Two bytes and a carry come in, a
// byte and four flags come out, and operation says what happens in between.
module alu (
    input  wire [3:0] operation,    // what to do: one of the names of alu_operations.vh
    input  wire [7:0] a,            // the value we work on
    input  wire [7:0] b,            // the value we combine it with, when there are two
    input  wire       carry_in,
    input  wire       decimal,      // 1: ADD and SUBTRACT count in decimal
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

    // Decimal mode. A byte holds two decimal digits, one in each half: $47 is
    // forty-seven. The adder above knows nothing of digits, so here the two
    // halves are added apart, the low one first. Four bits count up to 15, a
    // digit only up to 9: a digit that went past 9 gets 6 more, to jump over
    // the six codes from A to F, and it carries one into the next digit. In a
    // subtraction, a digit that went below 0 had to borrow: on its way down it
    // went through those six codes, and 6 is taken away from it.
    wire decimal_mode;
    assign decimal_mode = decimal & ((operation == ALU_ADD) | (operation == ALU_SUBTRACT));

    wire [4:0] low_half;        // the two low digits and the carry, added: five bits
    wire       low_carry;       // 1: a carry into the high digits (subtracting: no borrow)
    wire [4:0] high_half;       // the two high digits and that carry
    wire       high_carry;
    assign low_half   = a[3:0] + second[3:0] + first_carry;
    assign low_carry  = subtracting ? low_half[4]  : (low_half > 9);
    assign high_half  = a[7:4] + second[7:4] + low_carry;
    assign high_carry = subtracting ? high_half[4] : (high_half > 9);

    // Each digit, put right.
    wire [3:0] low_digit;
    wire [3:0] high_digit;
    assign low_digit  = (~subtracting &  low_carry)  ? low_half[3:0]  + 4'd6 :
                        ( subtracting & ~low_carry)  ? low_half[3:0]  - 4'd6 : low_half[3:0];
    assign high_digit = (~subtracting &  high_carry) ? high_half[3:0] + 4'd6 :
                        ( subtracting & ~high_carry) ? high_half[3:0] - 4'd6 : high_half[3:0];

    // The result: the first test that matches wins. An operation that is not
    // named here is one of the five jobs of the adder.
    assign result = decimal_mode                    ? {high_digit, low_digit} :
                    (operation == ALU_PASS)         ? a                  :
                    (operation == ALU_AND)          ? a & b              :
                    (operation == ALU_OR)           ? a | b              :
                    (operation == ALU_XOR)          ? a ^ b              :
                    (operation == ALU_SHIFT_LEFT)   ? {a[6:0], 1'b0}     :
                    (operation == ALU_ROTATE_LEFT)  ? {a[6:0], carry_in} :
                    (operation == ALU_SHIFT_RIGHT)  ? {1'b0, a[7:1]}     :
                    (operation == ALU_ROTATE_RIGHT) ? {carry_in, a[7:1]} :
                                                      sum[7:0];

    // The carry: in decimal, the carry of the high digit. Otherwise a shift
    // to the left pushes bit 7 out, a shift to the right pushes bit 0 out,
    // and the adder gives its ninth bit.
    assign carry_out = decimal_mode                    ? high_carry :
                       (operation == ALU_SHIFT_LEFT)   ? a[7] :
                       (operation == ALU_ROTATE_LEFT)  ? a[7] :
                       (operation == ALU_SHIFT_RIGHT)  ? a[0] :
                       (operation == ALU_ROTATE_RIGHT) ? a[0] :
                                                         sum[8];

    // In decimal, the 6502 works out N and V from the high digit before it
    // is put right, and Z from the sum of the adder above, as if it were not
    // in decimal at all. That is what the real chip does, and we copy it.

    // The overflow: the adder was given two numbers of the same sign, and
    // the sum came out with the other sign.
    assign overflow = (a[7] == second[7]) & ((decimal_mode ? high_half[3] : sum[7]) != a[7]);

    // Two flags that look at the result.
    assign negative = decimal_mode ? high_half[3]    : result[7];
    assign zero     = decimal_mode ? (sum[7:0] == 0) : (result == 0);
endmodule
