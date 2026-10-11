// Chapter 10, test bench for the address of the LEDs, with a program of its
// own, ports.s: a byte stored anywhere but at $8000 must not reach the LEDs.
`timescale 1ns/1ns
module ports_tb;
    reg         clk = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    // The same computer, with another file in its ROM.
    computer #(.PROGRAM("ports.hex")) dut (
        .clk      (clk),
        .reset    (1'b0),
        .step     (step),
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer   writes   = 0;
    integer   checked  = 0;
    integer   errors   = 0;
    reg [5:0] expected = 0;         // what the LEDs must show
    reg       wrote    = 0;         // a cycle that stored a byte has just ended
    reg       finished = 0;
    reg [15:0] written_at;

    // Follow every byte that the processor stores. One tick after the end of
    // its cycle, we look at the LEDs.
    always @(negedge clk) begin
        if (wrote) begin
            $display("a byte stored at %h: the LEDs show %0d", written_at, leds);
            checked = checked + 1;
            if (leds !== expected) begin
                $display("        ^ wrong, expected %0d", expected);
                errors = errors + 1;
            end
            if (writes == 7) begin
                finished = 1;
            end
        end
        wrote = 0;
        if (step & write) begin
            writes     = writes + 1;
            wrote      = 1;
            written_at = address;
            if (address == 16'h8000) begin
                expected = data_out[5:0];
            end
        end
    end

    // A test bench that waits for a processor needs a time limit. If the
    // seven bytes it is waiting for never come, it gives up after 1,000 ticks.
    initial begin
        #10000;
        $display("FAIL: ports, still waiting after 1,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("ports_tb.vcd");
        $dumpvars(0, ports_tb);

        wait (finished);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: ports, %0d bytes stored, only those at 8000 reach the LEDs", checked);
            $finish;
        end else begin
            $display("FAIL: ports, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
