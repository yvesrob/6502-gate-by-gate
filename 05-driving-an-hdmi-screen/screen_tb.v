// Chapter 5, test bench for the whole chain, up to the ten-bit codes:
// the raster, the pattern and the three encoders, wired as in screen.v.
// The test bench plays the monitor. It receives three codes at every tick,
// and from them alone it must find the picture again, and the two sync pulses.
// The PLL and the serializers are parts of the chip that the simulator
// does not know, so they are not here.
`timescale 1ns/1ns
module screen_tb;
    reg        clk = 0;

    // What the circuit produces, before the encoders.
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    raster scan (
        .clk     (clk),
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

    // The three encoders, connected exactly as in screen.v.
    wire [9:0] blue_code;
    wire [9:0] green_code;
    wire [9:0] red_code;

    tmds blue_encoder (
        .clk     (clk),
        .data    (blue),
        .control ({vsync, hsync}),
        .visible (visible),
        .code    (blue_code)
    );

    tmds green_encoder (
        .clk     (clk),
        .data    (green),
        .control (2'b00),
        .visible (visible),
        .code    (green_code)
    );

    tmds red_encoder (
        .clk     (clk),
        .data    (red),
        .control (2'b00),
        .visible (visible),
        .code    (red_code)
    );

    // One tick every 40 ns. In a simulation only the number of ticks matters.
    always #20 clk = ~clk;

    // ------------------------------------------------------------------
    // From here on, the monitor. It only looks at the three codes.
    // ------------------------------------------------------------------

    // Find a byte back from ten bits, as in tmds_tb.v.
    reg [7:0] plain;
    reg [7:0] decoded;
    integer   k;

    task decode;
        input [9:0] received;
        begin
            plain = received[9] ? ~received[7:0] : received[7:0];
            decoded[0] = plain[0];
            for (k = 1; k < 8; k = k + 1) begin
                decoded[k] = received[8] ?  (plain[k] ^ plain[k - 1])
                                         : ~(plain[k] ^ plain[k - 1]);
            end
        end
    endtask

    // Is this one of the four special codes? If it is, which control bits does it carry?
    reg       is_control;
    reg [1:0] control_bits;

    task look_for_control;
        input [9:0] received;
        begin
            is_control = 1;
            case (received)
                10'b1101010100: control_bits = 2'b00;
                10'b0010101011: control_bits = 2'b01;
                10'b0101010100: control_bits = 2'b10;
                10'b1010101011: control_bits = 2'b11;
                default:        is_control   = 0;
            endcase
        end
    endtask

    // What the monitor has found in the codes of this tick.
    reg       found_visible;
    reg       found_hsync;
    reg       found_vsync;
    reg [7:0] found_red;
    reg [7:0] found_green;
    reg [7:0] found_blue;

    // What the circuit had put in, one tick earlier. An encoder takes one tick:
    // the codes we receive now are those of the pixel before.
    reg       visible_before;
    reg       hsync_before;
    reg       vsync_before;
    reg [7:0] red_before;
    reg [7:0] green_before;
    reg [7:0] blue_before;

    // The picture file, written as in frame_tb.v of chapter 4.
    integer file;

    task write_byte;
        input [7:0] value;
        begin
            $fwrite(file, "%c", value);
        end
    endtask

    task write_number;
        input [31:0] value;
        begin
            write_byte(value[7:0]);
            write_byte(value[15:8]);
            write_byte(value[23:16]);
            write_byte(value[31:24]);
        end
    endtask

    task write_short;
        input [15:0] value;
        begin
            write_byte(value[7:0]);
            write_byte(value[15:8]);
        end
    endtask

    integer pixels      = 0;    // pixels found in the codes
    integer hsync_ticks = 0;    // ticks during which the monitor saw hsync low
    integer vsync_ticks = 0;    // the same for vsync
    integer errors      = 0;

    // The monitor looks half-way between two ticks, when the codes are steady.
    always @(negedge clk) begin
        // The blue pair tells us whether this is a pixel or a pause.
        look_for_control(blue_code);
        if (is_control) begin
            // A pause. The blue pair carries the two sync pulses...
            found_visible = 0;
            found_hsync   = control_bits[0];
            found_vsync   = control_bits[1];
            if (found_hsync == 0) hsync_ticks = hsync_ticks + 1;
            if (found_vsync == 0) vsync_ticks = vsync_ticks + 1;
            if (found_hsync !== hsync_before || found_vsync !== vsync_before) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: found hsync = %b and vsync = %b, the raster had sent %b and %b",
                                           found_hsync, found_vsync, hsync_before, vsync_before);
            end
            // ...and the other two pairs must be at rest.
            if (green_code !== 10'b1101010100 || red_code !== 10'b1101010100) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: during a pause, green sends %b and red sends %b", green_code, red_code);
            end
        end else begin
            // A pixel: three bytes to find back, and to write into the file.
            found_visible = 1;
            decode(blue_code);
            found_blue = decoded;
            decode(green_code);
            found_green = decoded;
            decode(red_code);
            found_red = decoded;
            write_byte(found_blue);
            write_byte(found_green);
            write_byte(found_red);
            pixels = pixels + 1;
            if (found_red !== red_before || found_green !== green_before || found_blue !== blue_before) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: found the color %h%h%h, the pattern had sent %h%h%h",
                                           found_red, found_green, found_blue,
                                           red_before, green_before, blue_before);
            end
        end

        // A pixel where the circuit had sent a pause, or the other way around?
        if (found_visible !== visible_before) begin
            errors = errors + 1;
            if (errors <= 10) $display("wrong: found visible = %b, the raster had sent %b", found_visible, visible_before);
        end

        // Remember what the circuit puts in now: its codes come out at the next tick.
        visible_before = visible;
        hsync_before   = hsync;
        vsync_before   = vsync;
        red_before     = red;
        green_before   = green;
        blue_before    = blue;
    end

    initial begin
        file = $fopen("decoded.bmp", "wb");

        // The same header as in chapter 4: 54 bytes.
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

        // The very first pixel is already waiting at the inputs of the encoders.
        // We note it now, just after the start: its codes come out at the first tick.
        #1;
        visible_before = visible;
        hsync_before   = hsync;
        vsync_before   = vsync;
        red_before     = red;
        green_before   = green;
        blue_before    = blue;

        // One frame is 800 x 525 ticks, and the codes of its last pixel come out
        // one tick later: we wait for that tick before closing the file.
        repeat (800 * 525 + 1) @(posedge clk);
        $fclose(file);

        $display("decoded.bmp: %0d pixels found in the codes", pixels);
        $display("ticks with hsync low:  %0d", hsync_ticks);
        $display("ticks with vsync low:  %0d", vsync_ticks);

        if (pixels !== 640 * 480) begin
            $display("wrong: expected %0d pixels", 640 * 480);
            errors = errors + 1;
        end
        // 525 lines with a pulse of 96 ticks each, and one pulse of 2 lines.
        if (hsync_ticks !== 525 * 96) begin
            $display("wrong: expected hsync low for %0d ticks", 525 * 96);
            errors = errors + 1;
        end
        if (vsync_ticks !== 2 * 800) begin
            $display("wrong: expected vsync low for %0d ticks", 2 * 800);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: screen, one picture of 640 x 480 found back from the codes");
            $finish;
        end else begin
            $display("FAIL: screen, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
