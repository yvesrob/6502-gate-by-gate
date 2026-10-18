// Chapter 18 uses the board from chapter 17. This file is a copy of it, unchanged.
// Chapter 17, on the board: the computer from chapter 16 and the picture
// from chapter 6, together. The bitmap and the colors are in the computer's
// memory now: its program draws, and the display shows what it draws, read
// through the second door of the two memories. The whole machine runs on one
// clock, the pixel clock from chapter 5: 25.2 MHz, so the processor does 12.6
// million cycles a second. Hold button S1 to start again: it is the reset.
// Button S2 is NMI, as in chapters 15 and 16.
module top (
    input  wire       clk,          // the board's 27 MHz clock
    input  wire       btn1,
    input  wire       btn2,
    output wire [5:0] led,
    output wire       tmds_clk_p,   // the four pairs of wires of the HDMI socket:
    output wire       tmds_clk_n,   // one for the pixel clock...
    output wire [2:0] tmds_d_p,     // ...and one for each color: blue, green, red
    output wire [2:0] tmds_d_n
);
    // The clocks, from chapter 5. Everything below ticks with pixel_clk.
    wire pixel_clk;
    wire fast_clk;
    wire locked;

    pll clocks (
        .clk       (clk),
        .pixel_clk (pixel_clk),
        .fast_clk  (fast_clk),
        .locked    (locked)
    );

    // How many ticks of the clock for one cycle of the processor. 2 is the
    // fastest the bus allows: 12.6 million cycles a second at 25.2 MHz.
    parameter PERIOD = 2;

    wire step;

    timer #(.PERIOD(PERIOD)) step_timer (
        .clk   (pixel_clk),
        .pulse (step)
    );

    // A button changes whenever a finger decides. One flip-flop makes it
    // change on a tick, like everything else in the circuit. S2 goes through
    // one too, to NMI. A bouncing S2 makes several NMIs; the program of this
    // chapter does the same thing for one or for several.
    reg reset   = 0;
    reg pressed = 0;

    always @(posedge pixel_clk) begin
        reset   <= btn1;
        pressed <= btn2;
    end

    // The computer, and the display's door into its picture.
    wire [5:0]  leds;
    wire [12:0] bitmap_address;
    wire [7:0]  bitmap_byte;
    wire [9:0]  colors_address;
    wire [7:0]  colors_byte;

    computer our_computer (
        .clk            (pixel_clk),
        .reset          (reset),
        .step           (step),
        .irq            (1'b0),         // nothing asks for IRQ on this board
        .nmi            (pressed),
        .leds           (leds),
        // On the board nobody watches the bus.
        .address        (),
        .data_in        (),
        .data_out       (),
        .write          (),
        .bitmap_address (bitmap_address),
        .bitmap_byte    (bitmap_byte),
        .colors_address (colors_address),
        .colors_byte    (colors_byte)
    );

    // On this board an LED lights up when its pin is LOW, so we invert them.
    assign led = ~leds;

    // The picture, from chapter 6: where the raster is, and which color goes
    // there. The display asks the computer for the two bytes.
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
        .bitmap_address  (bitmap_address),
        .bitmap_byte     (bitmap_byte),
        .colors_address  (colors_address),
        .colors_byte     (colors_byte),
        .red             (red),
        .green           (green),
        .blue            (blue),
        .visible_delayed (visible_delayed),
        .hsync_delayed   (hsync_delayed),
        .vsync_delayed   (vsync_delayed)
    );

    // From here to the end: screen.v from chapter 6. Three encoders, one for
    // each color, three serializers, and four pairs of pins.
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

    TLVDS_OBUF blue_pair  (.I(serial[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    TLVDS_OBUF green_pair (.I(serial[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    TLVDS_OBUF red_pair   (.I(serial[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    TLVDS_OBUF clock_pair (.I(pixel_clk), .O(tmds_clk_p),  .OB(tmds_clk_n));
endmodule
