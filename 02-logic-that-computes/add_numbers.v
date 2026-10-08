// Chapter 2, on the board: the eight-bit adder adds two numbers.
// Button S1 puts the first number on the adder, button S2 the second one.
module top (
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led
);
    // The two numbers. Change them, and build again.
    // Keep their sum under 64: six LEDs can only show six bits.
    parameter FIRST  = 23;
    parameter SECOND = 19;

    wire [7:0] a;
    wire [7:0] b;
    wire [7:0] sum;

    // A button that is not pressed puts zero on its side of the adder.
    assign a = btn1 ? FIRST  : 0;
    assign b = btn2 ? SECOND : 0;

    adder8 adder (
        .a         (a),
        .b         (b),
        .carry_in  (1'b0),      // no carry coming in
        .sum       (sum),
        .carry_out ()           // not used here
    );

    // The six LEDs show the six low bits of the sum, led[0] being worth one.
    // On this board an LED lights up when its pin is LOW, so we invert them.
    assign led = ~sum[5:0];
endmodule
