// Chapter 18, test bench for the whole picture: the computer, the raster and
// the display, wired as in board.v, on one clock. The program types, with S2
// pressed at the start as in computer_tb. When the LEDs show 22, the screen is
// full and has not scrolled yet, and the test bench stops the processor: it
// gives it no more steps, which changes nothing in the circuit. Then it takes
// one full frame from the display, writes it into frame.bmp, and checks every
// pixel against what the two memories of the picture hold, as in chapter 17.
//   vvp frame_tb.vvp           the picture when the LEDs show 22, just before
//                              the first scroll
//   vvp frame_tb.vvp +last     the picture when they show 56: the last screen
`timescale 1ns/1ns
module frame_tb;
    // The color of the border: the one display.v has.
    localparam BORDER = 14;

    reg         clk = 0;
    reg         s2  = 0;
    reg         s2_pressed = 0;
    integer     pressed_at = 0;
    reg         run = 1;        // 0: the test bench holds the processor still
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_out;
    wire        write;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    wire [12:0] bitmap_address;
    wire [7:0]  bitmap_byte;
    wire [9:0]  colors_address;
    wire [7:0]  colors_byte;

    computer our_computer (
        .clk            (clk),
        .reset          (1'b0),
        .step           (step & run),
        .irq            (1'b0),
        .nmi            (s2),
        .leds           (leds),
        .address        (address),
        .data_in        (),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (bitmap_address),
        .bitmap_byte    (bitmap_byte),
        .colors_address (colors_address),
        .colors_byte    (colors_byte)
    );

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

    display picture (
        .clk             (clk),
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

    // One tick every 40 ns, as for the pixel clock. In a simulation only the
    // number of ticks matters.
    always #20 clk = ~clk;

    // In the chip the memories start at zero.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) our_computer.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) our_computer.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) our_computer.the_colors.cells[n] = 8'h00;
    end

    // S2, pressed at the first write into the colors, for twenty cycles.
    integer cycle = 0;
    always @(negedge clk) begin
        if (step & run) begin
            cycle = cycle + 1;
            if (write && address >= 16'h9C00 && address <= 16'h9FFF && cycle < 100 && !s2 && !s2_pressed) begin
                s2 = 1;
                s2_pressed = 1;
                pressed_at = cycle;
            end
            if (s2 && cycle > pressed_at + 20) s2 = 0;
        end
    end

    // When to stop the processor: once the LEDs show 22, or with +last 56.
    integer stop_at  = 22;
    reg     watching = 0;       // 1: the test bench is taking the frame

    // The test bench reads the two memories, as they are, to know what each
    // pixel should be. And it has a palette of its own.
    reg  [3:0]  expected_number;
    wire [23:0] expected_color;
    palette expected_palette (
        .number (expected_number),
        .color  (expected_color)
    );

    integer x_before = 0;
    integer y_before = 0;
    integer pixel_x;
    integer pixel_y;
    reg [7:0] picture_byte;
    reg [7:0] colors_byte_now;
    reg [23:0] got_color;
    integer pixels = 0;
    integer lit    = 0;
    integer errors = 0;
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

    integer x_now;
    integer y_now;

    always @(posedge clk) begin
        // First everything as it is at the tick.
        x_now     = x;
        y_now     = y;
        got_color = {red, green, blue};
        if (watching) begin
            if (visible_delayed) begin
                if (y_before < 40 || y_before >= 440) begin
                    expected_number = BORDER;
                end else begin
                    pixel_x = x_before / 2;
                    pixel_y = (y_before - 40) / 2;
                    picture_byte    = our_computer.the_bitmap.cells[pixel_y * 40 + pixel_x / 8];
                    colors_byte_now = our_computer.the_colors.cells[(pixel_y / 8) * 40 + pixel_x / 8];
                    if (picture_byte[7 - pixel_x % 8]) begin
                        expected_number = colors_byte_now / 16;     // the ink
                        lit = lit + 1;
                    end else begin
                        expected_number = colors_byte_now % 16;     // the paper
                    end
                end
                #1;
                if (got_color !== expected_color) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: x = %0d, y = %0d shows %h, expected %h",
                                               x_before, y_before, got_color, expected_color);
                end
                write_byte(got_color[7:0]);
                write_byte(got_color[15:8]);
                write_byte(got_color[23:16]);
                pixels = pixels + 1;
            end
        end
        x_before = x_now;
        y_before = y_now;
    end

    initial begin
        if ($test$plusargs("last")) stop_at = 56;
        wait (leds == stop_at);
        @(negedge clk);
        run = 0;
        $display("cycle %0d: the LEDs show %0d; the processor is held still", cycle, leds);

        // Wait for the start of a frame: x and y at 0.
        wait (x == 0 && y == 0);
        @(negedge clk);

        file = $fopen("frame.bmp", "wb");
        write_byte("B");
        write_byte("M");
        write_number(54 + 640 * 480 * 3);
        write_number(0);
        write_number(54);
        write_number(40);
        write_number(640);
        write_number(-480);
        write_short(1);
        write_short(24);
        write_number(0);
        write_number(640 * 480 * 3);
        write_number(2835);
        write_number(2835);
        write_number(0);
        write_number(0);

        watching = 1;
        repeat (800 * 525 + 1) @(negedge clk);
        watching = 0;
        $fclose(file);

        $display("frame.bmp: %0d pixels written, %0d of them lit pixels of the picture (each pixel of the picture is four on the screen)",
                 pixels, lit);
        if (pixels !== 640 * 480) begin
            $display("wrong: expected %0d pixels", 640 * 480);
            errors = errors + 1;
        end
        if (errors == 0) begin
            $display("PASS: frame, %0d pixels checked against the two memories of the picture, the colors %h",
                     pixels, our_computer.the_colors.cells[0]);
            $finish;
        end else begin
            $display("FAIL: frame, %0d error(s)", errors);
            $fatal;
        end
    end

    // A limit, as in every test bench of a processor: 20 million ticks.
    initial begin
        #800_000_000;
        $display("FAIL: frame, still running after 20 million ticks; the LEDs show %0d", leds);
        $fatal;
    end
endmodule
