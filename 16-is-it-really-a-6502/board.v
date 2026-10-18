// Chapter 16, on the board: the board.v from chapter 15, at full speed, with
// another program in the ROM: the functional test of Klaus Dormann. The
// processor does 13.5 million cycles a second, and the six LEDs count the
// times the whole test went well, one more about every seven seconds. Hold
// button S1 to start again: it is the reset.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led
);
    // How many ticks of the clock for one cycle of the processor. 2 is the
    // fastest the bus allows: 13.5 million cycles a second. Chapters 10 to
    // 15 used 540,000, 50 cycles a second, slow enough to watch.
    parameter PERIOD = 2;

    wire step;

    timer #(.PERIOD(PERIOD)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    // A button changes whenever a finger decides. One flip-flop makes it
    // change on a tick, like everything else in the circuit. S2 goes through
    // one too, to NMI. At full speed the processor looks at NMI every 74
    // nanoseconds, so a bouncing button makes several NMIs. Here that does
    // not matter: the test expects no NMI at all, and the first one stops it,
    // in one of its traps.
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
