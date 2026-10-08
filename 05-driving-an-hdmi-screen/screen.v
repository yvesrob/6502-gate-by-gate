// Chapter 5, on the board: the test pattern of chapter 4, on a real monitor.
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

    // The picture of chapter 4: where we are, and which color goes there.
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    raster scan (
        .clk     (pixel_clk),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible)
    );

    pattern picture (
        .x       (x),
        .y       (y),
        .visible (visible),
        .red     (red),
        .green   (green),
        .blue    (blue)
    );

    // Three encoders, one for each color. Between the pictures, the blue one
    // carries the two sync pulses, and the other two carry nothing.
    wire [9:0] blue_code;
    wire [9:0] green_code;
    wire [9:0] red_code;

    tmds blue_encoder (
        .clk     (pixel_clk),
        .data    (blue),
        .control ({vsync, hsync}),
        .visible (visible),
        .code    (blue_code)
    );

    tmds green_encoder (
        .clk     (pixel_clk),
        .data    (green),
        .control (2'b00),
        .visible (visible),
        .code    (green_code)
    );

    tmds red_encoder (
        .clk     (pixel_clk),
        .data    (red),
        .control (2'b00),
        .visible (visible),
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
    // TLVDS_OBUF is the part of the chip that drives such a pair.
    TLVDS_OBUF blue_pair  (.I(serial[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    TLVDS_OBUF green_pair (.I(serial[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    TLVDS_OBUF red_pair   (.I(serial[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    TLVDS_OBUF clock_pair (.I(pixel_clk), .O(tmds_clk_p),  .OB(tmds_clk_n));
endmodule
