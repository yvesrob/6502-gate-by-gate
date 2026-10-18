// Chapter 16 uses the alu_operations from chapter 9. This file is a copy of it, unchanged.
// Chapter 9: the operations of the ALU, by name. This file is shared: alu.v
// reads it to know what it is asked, and whoever uses the ALU reads it to ask.
localparam ALU_PASS         = 0;    // a, unchanged
localparam ALU_ADD          = 1;    // a + b + carry_in
localparam ALU_SUBTRACT     = 2;    // a - b, and one more taken away if carry_in is 0
localparam ALU_COMPARE      = 3;    // a - b, whatever carry_in says
localparam ALU_AND          = 4;    // a AND b, bit by bit
localparam ALU_OR           = 5;    // a OR b
localparam ALU_XOR          = 6;    // a XOR b
localparam ALU_SHIFT_LEFT   = 7;    // a, one place to the left; a 0 comes in
localparam ALU_ROTATE_LEFT  = 8;    // the same, but carry_in comes in
localparam ALU_SHIFT_RIGHT  = 9;    // a, one place to the right; a 0 comes in
localparam ALU_ROTATE_RIGHT = 10;   // the same, but carry_in comes in
localparam ALU_INCREMENT    = 11;   // a + 1
localparam ALU_DECREMENT    = 12;   // a - 1
