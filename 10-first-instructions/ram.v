// Chapter 10 uses the ram from chapter 8. This file is a copy of it, unchanged.
// Chapter 8: the RAM. 32,768 bytes that the processor can read and write.
// It is the memory from chapter 6 with a way in: when write is 1 at a tick,
// the byte on data_in goes into the cell that address names.
module ram (
    input  wire        clk,
    input  wire [14:0] address,     // which byte: 0 to 32,767
    input  wire        write,       // 1: store data_in there at the next tick
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out     // the byte that was there, one tick later
);
    // No file fills this memory. In the simulator a cell that nobody has
    // written is unknown: it reads as x. In the chip it starts at zero.
    reg [7:0] cells [0:32767];

    always @(posedge clk) begin
        if (write) begin
            cells[address] <= data_in;
        end
        data_out <= cells[address];
    end
endmodule
