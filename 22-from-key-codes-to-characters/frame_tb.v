// Chapter 22, test bench for the whole picture: the computer, the raster and
// the display, wired as in board.v, on one clock, with the monitor in the ROM
// and someone who types to it on the keyboard: ch9350.v plays its shorter
// story (QUICK), c108.c10f and 8000: 15. The Mac only listens. At a chosen
// moment the test bench stops the processor: it gives it no more steps,
// which changes nothing in the circuit. Then it takes one full frame from
// the display, writes it into frame.bmp, and checks every pixel against what
// the two memories of the picture hold, as in chapters 17 to 21.
//   vvp frame_tb.vvp            when the two lines are typed, and answered
//   vvp frame_tb.vvp +title     when the Mac hears the first prompt: the
//                               title, and the prompt
//   vvp frame_tb.vvp +cursor    0.365 s after the two lines: nobody has typed
//                               for a quarter of a second, and the cursor
//                               shows after the last prompt (typing.s)
`timescale 1ns/1ns
module frame_tb;
    // The color of the border: the one display.v has.
    localparam BORDER = 14;

    reg         clk = 0;
    reg         run = 1;        // 0: the test bench holds the processor still
    wire        rx;
    wire        tx;
    wire        keyboard;
    reg         typing = 0;     // the person may begin to type
    wire        typed_all;
    wire [3:0]  phase;
    reg         go  = 0;        // the Mac never types here
    wire        done;
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
        .nmi            (1'b0),
        .leds           (leds),
        .address        (address),
        .data_in        (),
        .data_out       (data_out),
        .write          (write),
        .bitmap_address (bitmap_address),
        .bitmap_byte    (bitmap_byte),
        .colors_address (colors_address),
        .colors_byte    (colors_byte),
        .rx             (rx),
        .tx             (tx),
        .keyboard       (keyboard)
    );

    ch9350 #(.QUICK(1), .WIRE("wire-frame.txt")) module_and_keyboard (
        .go    (typing),
        .tx    (keyboard),
        .done  (typed_all),
        .phase (phase)
    );

    mac #(.FILE("readback.txt")) the_mac (
        .go   (go),
        .tx   (tx),
        .rx   (rx),
        .done (done)
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

    // The person types once the Mac hears the first prompt, except for the
    // title. The moment to stop: the first prompt, or the third, when the two
    // lines are typed and answered.
    integer cycle      = 0;
    reg     title      = 0;
    reg     cursor     = 0;
    integer answered   = 0;     // the cycle when the two lines were answered
    reg     stop_now   = 0;
    reg     watching   = 0;     // 1: the test bench is taking the frame
    initial title = $test$plusargs("title");
    initial cursor = $test$plusargs("cursor");
    always @(negedge clk) begin
        if (step & run) begin
            cycle = cycle + 1;
            if (the_mac.prompts == 1) begin
                if (title) stop_now = 1;
                else typing = 1;
            end
            if (typed_all && the_mac.prompts == 3) begin
                if (!cursor) stop_now = 1;
                else if (answered == 0) answered = cycle;
                else if (cycle == answered + 4_600_000) stop_now = 1;    // 0.365 s
            end
        end
    end

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
        wait (stop_now);
        @(negedge clk);
        @(negedge clk);
        run = 0;
        if (title) $display("cycle %0d: the Mac hears the first prompt; the processor is held still", cycle);
        else if (cursor) $display("cycle %0d: the two lines are typed and answered, and nobody has typed since; the processor is held still", cycle);
        else $display("cycle %0d: the two lines are typed and answered; the processor is held still", cycle);

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

    // A limit, as in every test bench of a processor: 20 million ticks (30
    // million with +cursor).
    initial begin
        #800_000_000;
        if (cursor) #400_000_000;
        $display("FAIL: frame, still running after %0d million ticks (phase %0d)", cursor ? 30 : 20, phase);
        $fatal;
    end
endmodule
