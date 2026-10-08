// Chapter 3: a timer. The clock is far too fast to watch, so we count
// its ticks, and once every PERIOD ticks we say "now".
module timer (
    input  wire clk,
    output wire pulse       // 1 during one tick out of PERIOD, 0 the rest of the time
);
    // How many ticks of the clock between two pulses.
    // The board's clock ticks 27,000,000 times a second: this is one second.
    parameter PERIOD = 27_000_000;

    // 25 bits count up to 33,554,431: enough for a little more than a second.
    reg [24:0] ticks = 0;

    always @(posedge clk) begin
        if (ticks == PERIOD - 1) begin
            ticks <= 0;
        end else begin
            ticks <= ticks + 1;
        end
    end

    // The pulse is up during the last tick of each round.
    assign pulse = (ticks == PERIOD - 1);
endmodule
