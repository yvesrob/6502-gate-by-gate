// Chapter 6, test bench for palette.v: each of the sixteen numbers must give
// the color written on its line of palette.hex. The test bench reads the file
// by its own means, and compares.
`timescale 1ns/1ns
module palette_tb;
    reg  [3:0]  number;
    wire [23:0] color;

    palette dut (
        .number (number),
        .color  (color)
    );

    // The test bench's own copy of the file.
    reg [23:0] in_file [0:15];

    integer n;
    integer errors  = 0;
    integer checked = 0;

    initial begin
        $dumpfile("palette_tb.vcd");
        $dumpvars(0, palette_tb);

        $readmemh("palette.hex", in_file);

        for (n = 0; n < 16; n = n + 1) begin
            number = n;
            #10;
            $display("color %2d = %h", number, color);
            checked = checked + 1;
            // A line missing from the file would leave its entry unknown (x).
            if (^in_file[n] === 1'bx) begin
                $display("           ^ wrong, palette.hex has no color for this number");
                errors = errors + 1;
            end else if (color !== in_file[n]) begin
                $display("           ^ wrong, the file says %h", in_file[n]);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("PASS: palette, %0d colors checked", checked);
            $finish;
        end else begin
            $display("FAIL: palette, %0d wrong color(s) out of %0d", errors, checked);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
