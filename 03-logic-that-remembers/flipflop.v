// Chapter 3: the flip-flop. One bit of memory.
module flipflop (
    input  wire clk,
    input  wire d,
    output reg  q = 0   // an output that is a register: it keeps its value
);
    // At every tick of the clock, q takes the value that d has at that instant.
    // Between two ticks q does not move, whatever d does.
    always @(posedge clk) begin
        q <= d;
    end
endmodule
