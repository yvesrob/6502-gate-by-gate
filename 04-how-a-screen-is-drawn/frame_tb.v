// Chapter 4, test bench for the whole picture: the raster and the pattern
// together, for one full frame. Every visible pixel goes into a file,
// frame.bmp, that any computer can open.
`timescale 1ns/1ns
module frame_tb;
    reg        clk = 0;
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    // The raster says where we are...
    raster scan (
        .clk     (clk),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible)
    );

    // ...and the pattern says which color goes there.
    pattern picture (
        .x       (x),
        .y       (y),
        .visible (visible),
        .red     (red),
        .green   (green),
        .blue    (blue)
    );

    // One tick every 40 ns. In a simulation only the number of ticks matters.
    always #20 clk = ~clk;

    integer file;
    integer pixels = 0;

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

    // We take one pixel at every tick, the way a real circuit would.
    // In a BMP file a pixel is three bytes: blue, then green, then red.
    always @(posedge clk) begin
        if (visible) begin
            write_byte(blue);
            write_byte(green);
            write_byte(red);
            pixels = pixels + 1;
        end
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

        // One frame is 800 x 525 ticks. The pixels are written as they go by.
        repeat (800 * 525) @(negedge clk);
        $fclose(file);

        $display("frame.bmp: %0d pixels written", pixels);
        if (pixels === 640 * 480) begin
            $display("PASS: frame, one picture of 640 x 480");
            $finish;
        end else begin
            $display("FAIL: frame, expected %0d pixels", 640 * 480);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
