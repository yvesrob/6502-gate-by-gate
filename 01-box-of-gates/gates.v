// Chapter 1, second circuit: six gates at once, one per LED.
module top (
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led
);
    // Six gates, all looking at the same two buttons, all the time.
    wire [5:0] gate;

    assign gate[0] =   btn1 & btn2;     // AND
    assign gate[1] =   btn1 | btn2;     // OR
    assign gate[2] =   btn1 ^ btn2;     // XOR
    assign gate[3] = ~(btn1 & btn2);    // NAND
    assign gate[4] = ~(btn1 | btn2);    // NOR
    assign gate[5] = ~(btn1 ^ btn2);    // XNOR

    // On this board an LED lights up when its pin is LOW,
    // so we invert all six before sending them out.
    assign led = ~gate;
endmodule
