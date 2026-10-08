// Chapter 1: the classic blinking LED.
module top (
    input  wire clk,   // the board's 27 MHz clock
    output wire led
);
    // The clock ticks 27,000,000 times a second,
    // so one second is 27,000,000 ticks.
    parameter ONE_SECOND = 27_000_000;

    // 24 bits only count up to 16,777,215. We need 25.
    reg [24:0] ticks = 0;
    reg        on    = 0;

    always @(posedge clk) begin
        if (ticks == ONE_SECOND - 1) begin
            ticks <= 0;
            on    <= ~on;
        end else begin
            ticks <= ticks + 1;
        end
    end

    // The LED lights up when its pin is LOW.
    assign led = ~on;
endmodule
