// Chapter 3: a counter. A register whose next value is its own value, plus one.
// Six bits, one per LED of the board: it counts from 0 to 63, then starts again.
module counter (
    input  wire       clk,
    input  wire       reset,    // 1: go back to zero at the next tick
    input  wire       enable,   // 1: count at the next tick
    output reg  [5:0] count = 0
);
    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
        end else if (enable) begin
            count <= count + 1;
        end
    end
endmodule
