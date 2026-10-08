// Chapter 3, on the board: a counter runs on the six LEDs, four steps a second.
// Hold button S1 to send it back to zero. Hold button S2 to make it wait.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led
);
    wire       step;
    wire [5:0] count;

    // A quarter of a second is 27,000,000 / 4 ticks of the clock.
    timer #(.PERIOD(27_000_000 / 4)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    // The counter moves when the timer says so, unless S2 is held down.
    counter step_counter (
        .clk    (clk),
        .reset  (btn1),
        .enable (step & ~btn2),
        .count  (count)
    );

    // The six LEDs show the count in binary, led[0] being worth one.
    // On this board an LED lights up when its pin is LOW, so we invert them.
    assign led = ~count;
endmodule
