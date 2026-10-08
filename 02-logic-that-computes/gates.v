// Chapter 2: the six gates of chapter 1, on their own.
// No buttons and no LEDs here: two inputs, and one output per gate.
module gates (
    input  wire a,
    input  wire b,
    output wire a_and_b,
    output wire a_or_b,
    output wire a_xor_b,
    output wire a_nand_b,
    output wire a_nor_b,
    output wire a_xnor_b
);
    assign a_and_b  =   a & b;      // 1 when both inputs are 1
    assign a_or_b   =   a | b;      // 1 when at least one input is 1
    assign a_xor_b  =   a ^ b;      // 1 when the two inputs differ
    assign a_nand_b = ~(a & b);     // the opposite of AND
    assign a_nor_b  = ~(a | b);     // the opposite of OR
    assign a_xnor_b = ~(a ^ b);     // the opposite of XOR
endmodule
