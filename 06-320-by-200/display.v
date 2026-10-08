// Chapter 6: the display. It takes the place of the test pattern of chapter 4.
// The color of each place now comes from two memories. One holds the picture:
// 320 x 200 pixels, one bit for each pixel. The other holds two colors for
// each cell of 8 x 8 pixels: one for the bits at 1, one for the bits at 0.
module display (
    input  wire       clk,                  // the pixel clock
    input  wire [9:0] x,                    // from the raster: where we are...
    input  wire [9:0] y,
    input  wire       visible,              // ...and its three signals
    input  wire       hsync,
    input  wire       vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output reg        visible_delayed = 0,  // the same three signals, one tick later:
    output reg        hsync_delayed   = 1,  // a memory takes one tick to answer, so
    output reg        vsync_delayed   = 1   // the colors come out one tick late too
);
    // The color of the border, as a number of the palette. 14 is a light blue.
    parameter BORDER = 14;

    // The window is 400 lines high, in the middle of the 480: lines 40 to 439.
    localparam TOP    = 40;
    localparam BOTTOM = 440;                // the first line under the window

    wire in_window;
    assign in_window = (y >= TOP) & (y < BOTTOM);

    // The line number, counted from the top of the window.
    // (Above the window this is nonsense, and nobody looks at it there.)
    wire [9:0] line;
    assign line = y - TOP;

    // Each pixel of our picture is a square of 2 x 2 on the screen. Leaving
    // bit 0 out divides by two: this is the pixel of the picture we are on.
    wire [8:0] pixel_x;                     // 0 to 319
    wire [7:0] pixel_y;                     // 0 to 199
    assign pixel_x = x[9:1];
    assign pixel_y = line[8:1];

    // A cell is 8 pixels wide and 8 pixels high. Leaving three more bits out
    // divides by eight.
    wire [5:0] column;                      // which cell across: 0 to 39
    wire [4:0] row;                         // which row of cells: 0 to 24
    assign column = pixel_x[8:3];
    assign row    = pixel_y[7:3];

    // The picture: 40 bytes for each line of pixels, 8,000 bytes in all.
    wire [12:0] bitmap_address;
    wire [7:0]  bitmap_byte;
    assign bitmap_address = pixel_y * 40 + column;

    memory #(.WORDS(8000), .FILE("bitmap.hex")) bitmap (
        .clk     (clk),
        .address (bitmap_address),
        .data    (bitmap_byte)
    );

    // The colors: one byte for each cell, 40 for each row, 1,000 bytes in all.
    wire [12:0] colors_address;
    wire [7:0]  colors_byte;
    assign colors_address = row * 40 + column;

    memory #(.WORDS(1000), .FILE("colors.hex")) colors (
        .clk     (clk),
        .address (colors_address),
        .data    (colors_byte)
    );

    // The two bytes arrive one tick after we asked for them. By then x has
    // moved on. So we keep, for one tick, what we will still need: which bit
    // of the byte, whether we were in the window, and the three signals.
    reg [2:0] bit_delayed       = 0;
    reg       in_window_delayed = 0;

    always @(posedge clk) begin
        bit_delayed       <= pixel_x[2:0];
        in_window_delayed <= in_window;
        visible_delayed   <= visible;
        hsync_delayed     <= hsync;
        vsync_delayed     <= vsync;
    end

    // A byte of the picture holds eight pixels. Bit 7 is the one on the left.
    wire pixel;
    assign pixel = bitmap_byte[7 - bit_delayed];

    // The two colors of the cell: the ink in the four high bits, for the pixels
    // at 1, and the paper in the four low bits, for the pixels at 0.
    wire [3:0] ink;
    wire [3:0] paper;
    assign ink   = colors_byte[7:4];
    assign paper = colors_byte[3:0];

    // Which of the sixteen colors goes here? The first test that matches wins.
    wire [3:0] number;
    assign number = ~in_window_delayed ? BORDER :
                    pixel              ? ink    : paper;

    wire [23:0] palette_color;
    palette sixteen_colors (
        .number (number),
        .color  (palette_color)
    );

    // Outside the picture everything is black.
    wire [23:0] color;
    assign color = visible_delayed ? palette_color : 24'h000000;

    assign red   = color[23:16];
    assign green = color[15:8];
    assign blue  = color[7:0];
endmodule
