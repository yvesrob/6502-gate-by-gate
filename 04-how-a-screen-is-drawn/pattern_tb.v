// Chapter 4, test bench for pattern.v: a few places on the screen
// where we know which color to expect.
`timescale 1ns/1ns
module pattern_tb;
    // The pattern has no clock: the test bench sets x and y itself.
    reg  [9:0] x;
    reg  [9:0] y;
    reg        visible;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    pattern dut (
        .x       (x),
        .y       (y),
        .visible (visible),
        .red     (red),
        .green   (green),
        .blue    (blue)
    );

    integer errors  = 0;
    integer checked = 0;

    // Go to one place, print the color found there, and compare.
    task check;
        input [9:0]  at_x;
        input [9:0]  at_y;
        input        is_visible;
        input [23:0] expected;      // red, green and blue side by side
        begin
            x       = at_x;
            y       = at_y;
            visible = is_visible;
            #10;
            // %h prints a value in hexadecimal.
            $display("x = %3d   y = %3d   color = %h%h%h", x, y, red, green, blue);
            checked = checked + 1;
            if ({red, green, blue} !== expected) begin
                $display("                      ^ wrong, expected %h", expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("pattern_tb.vcd");
        $dumpvars(0, pattern_tb);

        // The border: above the window, and under it.
        check(  0,   0, 1, 24'h3A4FA0);
        check(639,  39, 1, 24'h3A4FA0);
        check(320, 440, 1, 24'h3A4FA0);
        check(639, 479, 1, 24'h3A4FA0);

        // The eight bars, on the first line of the window.
        check(  0,  40, 1, 24'hFFFFFF);     // white
        check( 80,  40, 1, 24'hFFFF00);     // yellow
        check(160,  40, 1, 24'h00FFFF);     // cyan
        check(240,  40, 1, 24'h00FF00);     // green
        check(320,  40, 1, 24'hFF00FF);     // magenta
        check(400,  40, 1, 24'hFF0000);     // red
        check(480,  40, 1, 24'h0000FF);     // blue
        check(560,  40, 1, 24'h000000);     // black
        check( 79, 231, 1, 24'hFFFFFF);     // last line of the bars, last pixel of the white one

        // The checkerboard: it starts on line 232, with a light cell.
        check(  0, 232, 1, 24'hD8D8D8);
        check( 15, 247, 1, 24'hD8D8D8);     // the far corner of the same cell
        check( 16, 232, 1, 24'h404040);     // the cell on its right
        check(  0, 248, 1, 24'h404040);     // the cell under it
        check( 16, 248, 1, 24'hD8D8D8);     // and the one across
        check(639, 439, 1, 24'h404040);     // the last pixel of the window: a dark cell

        // Outside the picture everything is black, wherever x and y are.
        check(700,  40, 0, 24'h000000);
        check(  0, 500, 0, 24'h000000);

        if (errors == 0) begin
            $display("PASS: pattern, %0d places checked", checked);
            $finish;
        end else begin
            $display("FAIL: pattern, %0d wrong color(s) out of %0d", errors, checked);
            $fatal;
        end
    end
endmodule
