// Chapter 15, on the board: the board.v from chapter 10, with button S2 on
// NMI, and another program in the ROM. A light walks along the LEDs; press S2
// and the six LEDs light up for about a second, then the light goes on from
// where it was. Hold button S1 to start again: it is the reset.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    input  wire       btn1,
    input  wire       btn2,
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
    // change on a tick, like everything else in the circuit. S2 goes through
    // one too. It bounces as well, but the processor looks at NMI once a
    // cycle, every 20 milliseconds on the board: a bounce that is over in
    // less time than that is seen once.
    reg reset   = 0;
    reg pressed = 0;

    always @(posedge clk) begin
        reset   <= btn1;
        pressed <= btn2;
    end

    wire [5:0] leds;

    computer our_computer (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .irq      (1'b0),       // nothing asks for IRQ on this board
        .nmi      (pressed),
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
