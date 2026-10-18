// Chapter 22 uses the picture_ram from chapter 17. This file is a copy of it, unchanged.
// Chapter 17: a memory of the picture. It is the ram from chapter 8 with a
// second door, for the display. The processor reads and writes through the
// first; the display reads through the second, at every tick of the pixel
// clock. The two doors are independent: each has its own address, and both
// can be used at the same tick. The blocks of memory of the chip have two
// doors of their own, and this is what they are for.
module picture_ram (
    input  wire        clk,
    // The processor's door.
    input  wire [12:0] address,         // which byte
    input  wire        write,           // 1: store data_in there at the next tick
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,        // the byte that was there, one tick later
    // The display's door: it only reads.
    input  wire [12:0] display_address,
    output reg  [7:0]  display_data     // that byte, one tick later
);
    // How many bytes: an address of 13 bits reaches 8,191.
    parameter WORDS = 8192;

    // Nothing fills this memory: the processor does. In the simulator a
    // cell that nobody has written is unknown, x; in the chip it starts at zero.
    reg [7:0] cells [0:WORDS - 1];

    always @(posedge clk) begin
        if (write) begin
            cells[address] <= data_in;
        end
        data_out     <= cells[address];
        display_data <= cells[display_address];
    end
endmodule
