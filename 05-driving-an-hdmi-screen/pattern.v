// Chapter 5 uses the pattern of chapter 4. This file is a copy of it, unchanged.
// Chapter 4: the test pattern. It gives a color to every position of the raster.
// It lays the picture out the way our computer will: a window of 640 x 400 with
// a border above and below it and, inside the window, eight color bars, then
// the checkerboard of the cells that this picture will be divided into.
module pattern (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       visible,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);
    // Colors, written as on a web page: two hexadecimal digits for red,
    // two for green, two for blue. 24'h is a 24-bit number in hexadecimal.
    localparam BLACK  = 24'h000000;
    localparam BORDER = 24'h3A4FA0;     // a blue
    localparam LIGHT  = 24'hD8D8D8;     // the two grays of the checkerboard
    localparam DARK   = 24'h404040;

    // The window is 400 lines high, in the middle of the 480: lines 40 to 439.
    localparam TOP    = 40;
    localparam BOTTOM = 440;            // the first line under the window
    // The bars fill the first 192 lines of the window, the checkerboard the rest.
    localparam BARS   = 192;

    wire in_window;
    assign in_window = (y >= TOP) & (y < BOTTOM);

    // The line number, counted from the top of the window.
    // (Above the window this is nonsense, and nobody looks at it there.)
    wire [9:0] line;
    assign line = y - TOP;

    // Eight bars, 80 pixels wide. Which one are we in?
    wire [2:0] bar;
    assign bar = (x <  80) ? 0 :
                 (x < 160) ? 1 :
                 (x < 240) ? 2 :
                 (x < 320) ? 3 :
                 (x < 400) ? 4 :
                 (x < 480) ? 5 :
                 (x < 560) ? 6 : 7;

    // White, yellow, cyan, green, magenta, red, blue, black: the classic bars.
    // They come from counting in binary. Blue goes off at every other bar,
    // red every two bars, green every four.
    wire [23:0] bar_color;
    assign bar_color = { bar[1] ? 8'h00 : 8'hFF,        // red
                         bar[2] ? 8'h00 : 8'hFF,        // green
                         bar[0] ? 8'h00 : 8'hFF };      // blue

    // A cell is 16 pixels wide and 16 lines high. Bit 4 of a number changes
    // every 16: x[4] tells odd columns of cells from even ones, line[4] does
    // the same for the rows. Where the two differ, the cell is dark.
    wire dark_cell;
    assign dark_cell = x[4] ^ line[4];

    // One color for each place, the first test that matches wins.
    wire [23:0] color;
    assign color = ~visible      ? BLACK     :
                   ~in_window    ? BORDER    :
                   (line < BARS) ? bar_color :
                   dark_cell     ? DARK      : LIGHT;

    assign red   = color[23:16];
    assign green = color[15:8];
    assign blue  = color[7:0];
endmodule
