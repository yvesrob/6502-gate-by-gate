// Chapter 3: what the arrow <= really means.
// Two flip-flops trade their values at every tick, with no third one to help.
module swap (
    input  wire clk,
    output reg  a = 0,
    output reg  b = 1
);
    always @(posedge clk) begin
        a <= b;     // both lines read the values from BEFORE the tick,
        b <= a;     // and both flip-flops change together, ON the tick.
    end
endmodule
