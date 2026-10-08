// Chapter 4, test bench for raster.v. It does not look at a picture: it counts.
// How many ticks in a line, how many lines in a frame, how many visible pixels,
// and where the two sync pulses fall. Three frames go by, tick after tick.
`timescale 1ns/1ns
module raster_tb;
    reg        clk = 0;
    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       visible;

    raster dut (
        .clk     (clk),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible)
    );

    // One tick every 40 ns. In a simulation only the number of ticks matters.
    always #20 clk = ~clk;

    // What hsync and vsync were at the tick before, to see them change.
    reg hsync_before = 1;
    reg vsync_before = 1;

    // What the test bench counts.
    integer line_ticks   = 0;       // ticks since hsync last went low
    integer hsync_ticks  = 0;       // ticks spent with hsync low
    integer frame_lines  = 0;       // lines since vsync last went low
    integer frame_pixels = 0;       // visible pixels since vsync last went low
    integer vsync_ticks  = 0;       // ticks spent with vsync low
    integer hsync_pulses = 0;       // how many pulses so far
    integer vsync_pulses = 0;

    // The last value of each measurement, to print at the end.
    integer seen_line_ticks   = 0;
    integer seen_hsync_ticks  = 0;
    integer seen_hsync_x      = 0;
    integer seen_frame_lines  = 0;
    integer seen_frame_pixels = 0;
    integer seen_vsync_ticks  = 0;
    integer seen_vsync_y      = 0;

    integer lines_checked  = 0;
    integer frames_checked = 0;
    integer errors = 0;

    // We watch the raster the way a real circuit would: on every tick.
    // Each mistake is counted, and the first ten are printed.
    always @(posedge clk) begin
        line_ticks = line_ticks + 1;
        if (visible) begin
            frame_pixels = frame_pixels + 1;
        end
        if (hsync == 0) begin
            hsync_ticks = hsync_ticks + 1;
        end
        if (vsync == 0) begin
            vsync_ticks = vsync_ticks + 1;
        end

        // x and y must never leave their range.
        if (x > 799 || y > 524) begin
            errors = errors + 1;
            if (errors <= 10) $display("wrong: x = %0d, y = %0d is out of range", x, y);
        end

        // hsync goes low: one line later than the last time, and always at the same x.
        if (hsync_before == 1 && hsync == 0) begin
            if (hsync_pulses > 0) begin
                seen_line_ticks = line_ticks;
                lines_checked   = lines_checked + 1;
                if (line_ticks !== 800) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: a line of %0d ticks, expected 800", line_ticks);
                end
            end
            seen_hsync_x = x;
            if (x !== 656) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: hsync goes low at x = %0d, expected 656", x);
            end
            line_ticks   = 0;
            frame_lines  = frame_lines + 1;
            hsync_pulses = hsync_pulses + 1;
        end

        // hsync comes back up: how long was the pulse?
        if (hsync_before == 0 && hsync == 1) begin
            seen_hsync_ticks = hsync_ticks;
            if (hsync_ticks !== 96) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: an hsync pulse of %0d ticks, expected 96", hsync_ticks);
            end
            hsync_ticks = 0;
        end

        // vsync goes low: one frame later than the last time, and always on the same line.
        if (vsync_before == 1 && vsync == 0) begin
            if (vsync_pulses > 0) begin
                seen_frame_lines  = frame_lines;
                seen_frame_pixels = frame_pixels;
                frames_checked    = frames_checked + 1;
                if (frame_lines !== 525) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: a frame of %0d lines, expected 525", frame_lines);
                end
                if (frame_pixels !== 640 * 480) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: %0d visible pixels in a frame, expected %0d",
                                               frame_pixels, 640 * 480);
                end
            end
            seen_vsync_y = y;
            if (y !== 490) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: vsync goes low on line %0d, expected 490", y);
            end
            frame_lines  = 0;
            frame_pixels = 0;
            vsync_pulses = vsync_pulses + 1;
        end

        // vsync comes back up: the pulse must last two whole lines.
        if (vsync_before == 0 && vsync == 1) begin
            seen_vsync_ticks = vsync_ticks;
            if (vsync_ticks !== 2 * 800) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: a vsync pulse of %0d ticks, expected %0d",
                                           vsync_ticks, 2 * 800);
            end
            vsync_ticks = 0;
        end

        hsync_before = hsync;
        vsync_before = vsync;
    end

    initial begin
        $dumpfile("raster_tb.vcd");
        $dumpvars(0, raster_tb);

        // The waveform of three frames would be huge: we keep the first two lines.
        repeat (2 * 800) @(negedge clk);
        $dumpoff;

        // Three frames in all: that leaves two whole frames between vsync pulses.
        repeat (3 * 800 * 525 - 2 * 800) @(negedge clk);

        $display("ticks in a line:            %0d", seen_line_ticks);
        $display("ticks with hsync low:       %0d", seen_hsync_ticks);
        $display("hsync goes low at x =       %0d", seen_hsync_x);
        $display("lines in a frame:           %0d", seen_frame_lines);
        $display("visible pixels in a frame:  %0d", seen_frame_pixels);
        $display("ticks with vsync low:       %0d", seen_vsync_ticks);
        $display("vsync goes low on line      %0d", seen_vsync_y);

        if (frames_checked !== 2) begin
            $display("wrong: %0d whole frames seen, expected 2", frames_checked);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: raster, %0d lines and %0d frames checked", lines_checked, frames_checked);
            $finish;
        end else begin
            $display("FAIL: raster, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
