// Chapter 3, test bench for timer.v: with PERIOD set to 5, the pulse must
// come once every 5 ticks, and last one tick only.
`timescale 1ns/1ns
module timer_tb;
    reg  clk = 0;
    wire pulse;

    // In simulation nobody wants to wait 27 million ticks:
    // we build this timer with a PERIOD of 5 instead.
    timer #(.PERIOD(5)) dut (
        .clk   (clk),
        .pulse (pulse)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer tick   = 0;     // how many ticks so far
    integer last   = 0;     // the tick of the pulse before
    integer pulses = 0;     // how many pulses so far
    integer errors = 0;

    // We watch the pulse the way a real circuit would: on every tick.
    always @(posedge clk) begin
        tick = tick + 1;
        if (pulse) begin
            $display("tick %2d: pulse", tick);
            pulses = pulses + 1;
            if (tick - last !== 5) begin
                $display("         ^ wrong, %0d ticks after the one before, expected 5",
                         tick - last);
                errors = errors + 1;
            end
            last = tick;
        end
    end

    initial begin
        $dumpfile("timer_tb.vcd");
        $dumpvars(0, timer_tb);

        // Let 32 ticks go by.
        repeat (32) @(negedge clk);

        // One pulse every 5 ticks: in 32 ticks there must be exactly 6 of them.
        if (pulses !== 6) begin
            $display("wrong: %0d pulses in 32 ticks, expected 6", pulses);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: timer, %0d pulses in %0d ticks, 5 ticks apart", pulses, tick);
            $finish;
        end else begin
            $display("FAIL: timer, %0d error(s)", errors);
            $fatal;
        end
    end
endmodule
