// Chapter 2, on the board: the half adder adds the two buttons.
// A button counts for 1 while it is pressed, and for 0 otherwise.
module top (
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led
);
    wire sum;
    wire carry;

    half_adder adder (
        .a     (btn1),
        .b     (btn2),
        .sum   (sum),
        .carry (carry)
    );

    // The answer is a two-bit number: led[1] is worth two, led[0] is worth one.
    // On this board an LED lights up when its pin is LOW, so we invert both.
    assign led[0] = ~sum;
    assign led[1] = ~carry;

    // The other four LEDs stay off: a HIGH pin means off.
    assign led[5:2] = 4'b1111;
endmodule
