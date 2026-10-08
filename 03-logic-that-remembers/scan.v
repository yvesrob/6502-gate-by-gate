// Chapter 3, on the board: one light runs back and forth along the six LEDs,
// ten steps a second.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    output wire [5:0] led
);
    wire       step;
    wire [5:0] light;

    // A tenth of a second is 27,000,000 / 10 ticks of the clock.
    timer #(.PERIOD(27_000_000 / 10)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    scanner light_scanner (
        .clk   (clk),
        .step  (step),
        .light (light)
    );

    // On this board an LED lights up when its pin is LOW, so we invert them.
    assign led = ~light;
endmodule
