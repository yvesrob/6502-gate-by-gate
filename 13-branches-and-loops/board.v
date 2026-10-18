// Chapter 13, on the board: the board.v from chapter 10, with another program
// in the ROM. A loop computes the Collatz sequence from 7 and shows it on
// the LEDs, until it reaches 1 and stops. Hold button S1 to start it again.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    input  wire       btn1,
    output wire [5:0] led
);
    // How many ticks of the clock for one cycle of the processor. 540,000
    // ticks make 50 cycles a second. The fastest the bus allows is 2.
    parameter PERIOD = 540_000;

    wire step;

    timer #(.PERIOD(PERIOD)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    // A button changes whenever a finger decides. One flip-flop makes it
    // change on a tick, like everything else in the circuit.
    reg reset = 0;

    always @(posedge clk) begin
        reset <= btn1;
    end

    wire [5:0] leds;

    computer our_computer (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .leds     (leds),
        // On the board nobody watches the bus.
        .address  (),
        .data_in  (),
        .data_out (),
        .write    ()
    );

    // On this board an LED lights up when its pin is LOW, so we invert them.
    assign led = ~leds;
endmodule
