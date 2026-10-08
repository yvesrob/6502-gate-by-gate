// Chapter 1, first circuit: one gate between two buttons and an LED.
module top (
    input  wire btn1,
    input  wire btn2,
    output wire led
);
    // On this board an LED lights up when its pin is LOW,
    // so we invert the result of the gate before sending it out.
    assign led = ~(btn1 & btn2);
endmodule
