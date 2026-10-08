// Chapter 6, test bench for the whole picture: the raster and the display
// together, for one full frame. Every visible pixel goes into frame.bmp, and
// every one of them is compared with what the two files say it should be.
`timescale 1ns/1ns
module frame_tb;
    // The color of the border: the test bench chooses it and tells the display.
    localparam BORDER = 14;

    reg        clk = 0;
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;
    wire       visible_delayed;
    wire       hsync_delayed;
    wire       vsync_delayed;

    raster scan (
        .clk     (clk),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible)
    );

    display #(.BORDER(BORDER)) picture (
        .clk             (clk),
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

    // One tick every 40 ns. In a simulation only the number of ticks matters.
    always #20 clk = ~clk;

    // The test bench reads the two files on its own, into its own tables...
    reg [7:0] bitmap [0:7999];
    reg [7:0] colors [0:999];
    initial begin
        $readmemh("bitmap.hex", bitmap);
        $readmemh("colors.hex", colors);
    end

    // ...and it has a palette of its own, to turn a number into a color.
    reg  [3:0]  expected_number;
    wire [23:0] expected_color;
    palette expected_palette (
        .number (expected_number),
        .color  (expected_color)
    );

    // What the display shows at a tick belongs to the place where the raster
    // was at the tick before. So the test bench remembers that place.
    integer x_before = 0;
    integer y_before = 0;
    integer x_now;
    integer y_now;

    // Where that place falls in the picture, worked out with plain arithmetic.
    integer pixel_x;
    integer pixel_y;
    integer cell_number;
    reg [7:0] picture_byte;
    reg [7:0] colors_byte;

    // What the display gave at this tick.
    reg [23:0] got_color;
    reg        got_visible;
    reg        got_hsync;
    reg        got_vsync;

    // What hsync and vsync were at the tick before, to see them change.
    reg hsync_before = 1;
    reg vsync_before = 1;

    // What the test bench counts.
    integer pixels      = 0;    // visible pixels so far
    integer blank       = 0;    // ticks since the last visible pixel
    integer line_pixels = 0;    // visible pixels since hsync last went low
    integer hsync_ticks = 0;    // ticks spent with hsync low
    integer vsync_ticks = 0;    // ticks spent with vsync low
    integer hsync_pulses = 0;
    integer vsync_pulses = 0;
    integer errors = 0;

    integer file;

    // A BMP file is a list of bytes. With %c, $fwrite writes exactly one byte.
    task write_byte;
        input [7:0] value;
        begin
            $fwrite(file, "%c", value);
        end
    endtask

    // The numbers of the header take four bytes each, the low byte first...
    task write_number;
        input [31:0] value;
        begin
            write_byte(value[7:0]);
            write_byte(value[15:8]);
            write_byte(value[23:16]);
            write_byte(value[31:24]);
        end
    endtask

    // ...except two of them, which take two bytes.
    task write_short;
        input [15:0] value;
        begin
            write_byte(value[7:0]);
            write_byte(value[15:8]);
        end
    endtask

    always @(posedge clk) begin
        // First we take everything as it is at the tick.
        x_now       = x;
        y_now       = y;
        got_color   = {red, green, blue};
        got_visible = visible_delayed;
        got_hsync   = hsync_delayed;
        got_vsync   = vsync_delayed;

        if (got_visible) begin
            // A pixel can only be shown for a place that is inside the picture.
            if (x_before > 639 || y_before > 479) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: a pixel is shown for x = %0d, y = %0d, outside the picture",
                                           x_before, y_before);
            end

            // Which color should the place of the tick before have?
            if (y_before < 40 || y_before >= 440) begin
                expected_number = BORDER;
            end else begin
                pixel_x = x_before / 2;                     // 0 to 319
                pixel_y = (y_before - 40) / 2;              // 0 to 199
                picture_byte = bitmap[pixel_y * 40 + pixel_x / 8];
                cell_number  = (pixel_y / 8) * 40 + pixel_x / 8;
                colors_byte  = colors[cell_number];
                // % gives the remainder of a division: the pixel's place in its byte.
                if (picture_byte[7 - pixel_x % 8]) begin
                    expected_number = colors_byte / 16;     // the ink
                end else begin
                    expected_number = colors_byte % 16;     // the paper
                end
            end
            #1;     // give the test bench's own palette the time to answer

            if (got_color !== expected_color) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: x = %0d, y = %0d shows %h, expected %h",
                                           x_before, y_before, got_color, expected_color);
            end

            // In a BMP file a pixel is three bytes: blue, then green, then red.
            write_byte(got_color[7:0]);
            write_byte(got_color[15:8]);
            write_byte(got_color[23:16]);
            pixels      = pixels + 1;
            line_pixels = line_pixels + 1;
        end

        // The delayed sync pulses must still be where a monitor expects them.
        // hsync goes low 16 ticks after the last pixel of a line.
        if (hsync_before == 1 && got_hsync == 0) begin
            if (line_pixels > 0 && blank !== 16) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: hsync goes low %0d ticks after the last pixel, expected 16", blank);
            end
            if (line_pixels !== 0 && line_pixels !== 640) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: a line of %0d pixels, expected 640", line_pixels);
            end
            line_pixels  = 0;
            hsync_pulses = hsync_pulses + 1;
        end
        if (got_hsync == 0) begin
            hsync_ticks = hsync_ticks + 1;
        end
        if (hsync_before == 0 && got_hsync == 1) begin
            if (hsync_ticks !== 96) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: an hsync pulse of %0d ticks, expected 96", hsync_ticks);
            end
            hsync_ticks = 0;
        end

        // vsync goes low 10 lines and the end of a line after the last pixel:
        // 160 + 10 x 800 ticks.
        if (vsync_before == 1 && got_vsync == 0) begin
            if (blank !== 160 + 10 * 800) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: vsync goes low %0d ticks after the last pixel, expected %0d",
                                           blank, 160 + 10 * 800);
            end
            vsync_pulses = vsync_pulses + 1;
        end
        if (got_vsync == 0) begin
            vsync_ticks = vsync_ticks + 1;
        end
        if (vsync_before == 0 && got_vsync == 1) begin
            if (vsync_ticks !== 2 * 800) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: a vsync pulse of %0d ticks, expected %0d",
                                           vsync_ticks, 2 * 800);
            end
            vsync_ticks = 0;
        end

        if (got_visible) begin
            blank = 0;
        end else begin
            blank = blank + 1;
        end
        hsync_before = got_hsync;
        vsync_before = got_vsync;
        x_before     = x_now;
        y_before     = y_now;
    end

    initial begin
        // "wb" opens the file to write bytes into it, with nothing changed on the way.
        file = $fopen("frame.bmp", "wb");

        // The header: the 54 bytes that every BMP file begins with.
        write_byte("B");
        write_byte("M");
        write_number(54 + 640 * 480 * 3);   // the size of the whole file
        write_number(0);                    // not used
        write_number(54);                   // where the pixels begin
        write_number(40);                   // the size of what is left of the header
        write_number(640);                  // the width of the picture
        write_number(-480);                 // its height. Negative: the top line comes first
        write_short(1);                     // always 1
        write_short(24);                    // 24 bits for each pixel
        write_number(0);                    // no compression
        write_number(640 * 480 * 3);        // the size of the pixels
        write_number(2835);                 // pixels per meter, across...
        write_number(2835);                 // ...and down: 72 per inch
        write_number(0);                    // no table of colors
        write_number(0);

        // One frame is 800 x 525 ticks, and the colors come one tick late.
        repeat (800 * 525 + 1) @(negedge clk);
        $fclose(file);

        $display("frame.bmp: %0d pixels written", pixels);
        if (pixels !== 640 * 480) begin
            $display("wrong: expected %0d pixels", 640 * 480);
            errors = errors + 1;
        end
        if (vsync_pulses !== 1) begin
            $display("wrong: %0d vsync pulses in one frame, expected 1", vsync_pulses);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: frame, %0d pixels checked against the two files", pixels);
            $finish;
        end else begin
            $display("FAIL: frame, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
