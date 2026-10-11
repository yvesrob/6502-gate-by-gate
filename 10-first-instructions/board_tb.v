// Chapter 10, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must count, upside down (an LED is lit when
// its pin is LOW), and button S1 must start the count again.
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

    integer ticks   = 0;        // ticks of the clock since the beginning
    integer changed = 0;        // the tick of the last change
    integer changes = 0;
    integer checked = 0;
    integer errors  = 0;
    reg [5:0] before   = 6'b111111;     // all the pins HIGH: no LED is lit, the count is 0
    reg [5:0] expected = 1;             // the number we expect at the next change
    reg [5:0] number;
    reg       timed    = 0;             // is there a change before this one to measure from?

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    // Each time the pins change, they must show the next number.
    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            number  = ~led;         // lit means LOW: turn the pins over to read the number
            if (changes <= 4) begin
                $display("tick %4d: the pins show %b, the LEDs count %0d", ticks, led, number);
            end
            checked = checked + 1;
            if (number !== expected) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the LEDs count %0d, expected %0d", number, expected);
            end
            // Eleven cycles for one lap of the loop.
            if (timed && ticks - changed !== 11 * PERIOD) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: %0d ticks since the last change, expected %0d",
                                           ticks - changed, 11 * PERIOD);
            end
            timed    = 1;
            changed  = ticks;
            before   = led;
            expected = number + 6'd1;
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

        // Count past 63 and around.
        wait (changes == 70);
        $display("tick %4d: the pins show %b, the LEDs count %0d", ticks, led, ~led);
        $dumpoff;

        // Hold S1 for a while: everything stops. Release it: the program
        // starts again, and its first act is to put zero on the LEDs.
        @(negedge clk);
        btn1 = 1;
        repeat (50) @(negedge clk);
        if (led !== before) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved while S1 was held down");
        end
        btn1 = 0;
        $display("S1 held for 50 ticks, then released");
        changes  = 0;
        expected = 0;
        timed    = 0;
        wait (changes == 3);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, %0d ticks apart", checked, 11 * PERIOD);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
