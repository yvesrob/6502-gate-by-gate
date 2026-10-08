// Chapter 4, on the board: two clocks, and one second counted on each of them.
// led[0] counts the 27 MHz of the crystal, led[1] the 25.2 MHz of the pixel clock.
// If the pixel clock is right, the two LEDs change together for as long as you watch.
module top (
    input  wire       clk,      // the board's 27 MHz clock
    output wire [5:0] led
);
    wire pixel_clk;

    pll pixel_pll (
        .clk       (clk),
        .pixel_clk (pixel_clk)
    );

    // One second is 27,000,000 ticks of one clock and 25,200,000 ticks of the other.
    wire crystal_second;
    wire pixel_second;

    timer #(.PERIOD(27_000_000)) crystal_timer (
        .clk   (clk),
        .pulse (crystal_second)
    );

    timer #(.PERIOD(25_200_000)) pixel_timer (
        .clk   (pixel_clk),
        .pulse (pixel_second)
    );

    // Each LED has its own flip-flop, on its own clock, and flips once a second.
    // No signal goes from one clock to the other.
    reg crystal_led = 0;
    reg pixel_led   = 0;

    always @(posedge clk) begin
        if (crystal_second) begin
            crystal_led <= ~crystal_led;
        end
    end

    always @(posedge pixel_clk) begin
        if (pixel_second) begin
            pixel_led <= ~pixel_led;
        end
    end

    // On this board an LED lights up when its pin is LOW, so we invert both.
    assign led[0] = ~crystal_led;
    assign led[1] = ~pixel_led;

    // The other four LEDs stay off: a HIGH pin means off.
    assign led[5:2] = 4'b1111;
endmodule
