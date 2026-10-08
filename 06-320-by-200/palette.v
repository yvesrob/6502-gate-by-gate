// Chapter 6: the palette. Our pictures use sixteen colors, numbered 0 to 15.
// The palette says what each number looks like on the screen: red, green and
// blue, eight bits each. The colors themselves are not written here. They are
// in a file, palette.hex, one on each line: to change them, change the file.
module palette (
    input  wire [3:0]  number,
    output wire [23:0] color
);
    parameter FILE = "palette.hex";

    // A third memory, and a very small one: sixteen entries of 24 bits.
    reg [23:0] entries [0:15];

    initial begin
        $readmemh(FILE, entries);
    end

    // No clock this time: the color follows the number at once, like a gate.
    // A memory this small is not made of block RAM but of lookup tables.
    assign color = entries[number];
endmodule
