// Chapter 6, on the board: a picture of 320 x 200 pixels in sixteen colors,
// read from two memories and shown on a real monitor.
module top (
    input  wire       clk,          // the board's 27 MHz clock
    output wire       tmds_clk_p,   // the four pairs of wires of the HDMI socket:
    output wire       tmds_clk_n,   // one for the pixel clock...
    output wire [2:0] tmds_d_p,     // ...and one for each color: blue, green, red
    output wire [2:0] tmds_d_n
);
    // The clocks.
    wire pixel_clk;
    wire fast_clk;
    wire locked;

    pll clocks (
        .clk       (clk),
        .pixel_clk (pixel_clk),
        .fast_clk  (fast_clk),
        .locked    (locked)
    );

    // Where we are.
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;

    raster scan (
        .clk     (pixel_clk),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible)
    );

    // Which color goes there. The display answers one tick late, and gives
    // the three signals of the raster back with the same delay.
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;
    wire       hsync_delayed;
    wire       vsync_delayed;
    wire       visible_delayed;

    display picture (
        .clk             (pixel_clk),
        .x               (x),
        .y               (y),
        .visible         (visible),
        .hsync           (hsync),
        .vsync           (vsync),
        .red             (red),
        .green           (green),
        .blue            (blue),
        .visible_delayed (visible_delayed),
        .hsync_delayed   (hsync_delayed),
        .vsync_delayed   (vsync_delayed)
    );

    // Three encoders, one for each color. They get the delayed signals, the
    // ones that are in step with the colors.
    wire [9:0] blue_code;
    wire [9:0] green_code;
    wire [9:0] red_code;

    tmds blue_encoder (
        .clk     (pixel_clk),
        .data    (blue),
        .control ({vsync_delayed, hsync_delayed}),
        .visible (visible_delayed),
        .code    (blue_code)
    );

    tmds green_encoder (
        .clk     (pixel_clk),
        .data    (green),
        .control (2'b00),
        .visible (visible_delayed),
        .code    (green_code)
    );

    tmds red_encoder (
        .clk     (pixel_clk),
        .data    (red),
        .control (2'b00),
        .visible (visible_delayed),
        .code    (red_code)
    );

    // Three serializers: ten bits in, one wire out.
    wire [2:0] serial;

    serializer blue_serializer (
        .pixel_clk (pixel_clk),
        .fast_clk  (fast_clk),
        .reset     (~locked),
        .code      (blue_code),
        .serial    (serial[0])
    );

    serializer green_serializer (
        .pixel_clk (pixel_clk),
        .fast_clk  (fast_clk),
        .reset     (~locked),
        .code      (green_code),
        .serial    (serial[1])
    );

    serializer red_serializer (
        .pixel_clk (pixel_clk),
        .fast_clk  (fast_clk),
        .reset     (~locked),
        .code      (red_code),
        .serial    (serial[2])
    );

    // Four pairs of pins. Each pair carries one signal and its opposite.
    TLVDS_OBUF blue_pair  (.I(serial[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    TLVDS_OBUF green_pair (.I(serial[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    TLVDS_OBUF red_pair   (.I(serial[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    TLVDS_OBUF clock_pair (.I(pixel_clk), .O(tmds_clk_p),  .OB(tmds_clk_n));
endmodule
