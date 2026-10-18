// Chapter 11, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must show the steps of the light, upside down
// (an LED is lit when its pin is LOW), and button S1 must start it again.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    wire [5:0] led;

    // On the board one cycle of the processor lasts 540,000 ticks, and the
    // simulator would take a long time. Here the processor runs at full speed.
    parameter PERIOD = 2;

    top #(.PERIOD(PERIOD)) dut (
        .clk  (clk),
        .btn1 (btn1),
        .led  (led)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // The eight steps of the light, as sweep.s writes them.
    reg [5:0] steps [0:7];
    initial begin
        steps[0] = 6'b000011;  steps[1] = 6'b000110;  steps[2] = 6'b001100;  steps[3] = 6'b011000;
        steps[4] = 6'b110000;  steps[5] = 6'b011000;  steps[6] = 6'b001100;  steps[7] = 6'b000110;
    end

    integer ticks   = 0;        // ticks of the clock since the beginning
    integer changed = 0;        // the tick of the last change
    integer changes = 0;
    integer checked = 0;
    integer errors  = 0;
    integer cycles;             // cycles of the processor from one change to the next
    reg [5:0] before   = 6'b111111;     // all the pins HIGH: no LED is lit
    reg [7:0] x        = 0;             // the X of the next step: which byte of the table
    reg [5:0] lights;
    reg       timed    = 0;             // is there a change before this one to measure from?

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    // Each time the pins change, they must show the next step.
    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            lights  = ~led;         // lit means LOW: turn the pins over to read the LEDs
            if (changes <= 9 || changes == 244 || changes == 245 || changes == 257) begin
                $display("tick %4d: the pins show %b, the LEDs show %b (X = %0d)", ticks, led, lights, x);
            end
            checked = checked + 1;
            if (lights !== steps[x % 8]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", lights, steps[x % 8]);
            end
            // Thirteen cycles from one step to the next, fourteen when the
            // byte of the table is on the next page: from X = 244 on.
            // (The table begins at $C00C: 12 + X past 255 is the next page.)
            cycles = (12 + x > 255) ? 14 : 13;
            if (timed && ticks - changed !== cycles * PERIOD) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: %0d ticks since the last change, expected %0d",
                                           ticks - changed, cycles * PERIOD);
            end
            timed   = 1;
            changed = ticks;
            before  = led;
            x       = x + 1;
        end
    end

    // A test bench that waits for a processor needs a time limit. If the
    // changes it is waiting for never come, it gives up after 20,000 ticks.
    initial begin
        #200000;
        $display("FAIL: board, still waiting after 20,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("board_tb.vcd");
        $dumpvars(0, board_tb);

        // A whole round of X, and a little more.
        wait (changes == 260);
        $display("tick %4d: the pins show %b, the LEDs show %b", ticks, led, ~led);
        $dumpoff;

        // Hold S1 for a while: everything stops. Release it: the program
        // starts again, and the light with it, from the first step.
        @(negedge clk);
        btn1 = 1;
        repeat (50) @(negedge clk);
        if (led !== before) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved while S1 was held down");
        end
        btn1 = 0;
        $display("S1 held for 50 ticks, then released");
        changes = 0;
        x       = 0;
        timed   = 0;
        wait (changes == 3);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, %0d or %0d ticks apart",
                     checked, 13 * PERIOD, 14 * PERIOD);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
