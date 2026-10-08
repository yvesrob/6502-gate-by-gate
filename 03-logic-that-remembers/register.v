// Chapter 3: a register. Eight flip-flops side by side, on the same clock.
module register (
    input  wire       clk,
    input  wire       load,     // 1: take the new value at the next tick
    input  wire [7:0] d,
    output reg  [7:0] q = 0
);
    always @(posedge clk) begin
        if (load) begin
            q <= d;
        end
        // There is no else: when load is 0, q simply keeps what it has.
    end
endmodule
