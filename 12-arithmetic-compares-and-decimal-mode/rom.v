// Chapter 12 uses the rom from chapter 8. This file is a copy of it, unchanged.
// Chapter 8: the ROM. 16,384 bytes that hold the program. The processor can
// read them and nothing can change them: they are filled from a file when the
// circuit is built. This is the memory from chapter 6, with one more bit of address.
module rom (
    input  wire        clk,
    input  wire [13:0] address,     // which byte we want: 0 to 16,383
    output reg  [7:0]  data         // that byte, one tick later
);
    // The file that fills the ROM: one byte on each line, two hexadecimal digits.
    parameter FILE = "rom.hex";

    reg [7:0] cells [0:16383];

    initial begin
        $readmemh(FILE, cells);
    end

    // We give an address at one tick, and the byte comes out at the next.
    always @(posedge clk) begin
        data <= cells[address];
    end
endmodule
