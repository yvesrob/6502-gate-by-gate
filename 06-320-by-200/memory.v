// Chapter 6: a memory. A table of bytes that the chip holds, filled from a
// file when the circuit is loaded. For now nobody writes into it: only the
// display reads it. The processor will get its way in, much later.
module memory (
    input  wire        clk,
    input  wire [12:0] address,     // which byte we want
    output reg  [7:0]  data         // that byte, one tick later
);
    // How many bytes the memory holds, and the file that fills it.
    // An address of 13 bits reaches 8,191: enough for our largest memory.
    parameter WORDS = 8000;
    parameter FILE  = "bitmap.hex";

    // Not one register this time: WORDS registers of eight bits, under one name.
    reg [7:0] cells [0:WORDS - 1];

    // The file is a text file: one byte on each line, two hexadecimal digits.
    initial begin
        $readmemh(FILE, cells);
    end

    // We give an address at one tick, and the byte comes out at the next.
    always @(posedge clk) begin
        data <= cells[address];
    end
endmodule
