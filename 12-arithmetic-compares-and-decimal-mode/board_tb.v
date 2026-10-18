// Chapter 12, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must show the seconds of the stopwatch,
// upside down (an LED is lit when its pin is LOW), one change every 50
// cycles, and button S1 must start the stopwatch again from zero.
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

    // A number of seconds, as the program writes it: two decimal digits in
    // one byte, of which the LEDs show the six low bits.
    function [5:0] lights_for;
        input integer second;
        begin
            lights_for = ((second % 100) / 10) * 16 + second % 10;
        end
    endfunction

    integer ticks   = 0;        // ticks of the clock since the beginning
    integer changed = 0;        // the tick of the last change
    integer changes = 0;
    integer checked = 0;
    integer errors  = 0;
    integer second  = 1;        // the seconds the next change must show
    reg [5:0] before   = 6'b111111;     // all the pins HIGH: no LED is lit
    reg [5:0] lights;
    reg       timed    = 0;             // is there a change before this one to measure from?

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    // Each time the pins change, they must show the next second.
    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            lights  = ~led;         // lit means LOW: turn the pins over to read the LEDs
            if (changes <= 10 || (changes >= 39 && changes <= 41) || changes >= 99) begin
                $display("tick %5d: the pins show %b, the LEDs show %b (%0d s)", ticks, led, lights, second);
            end
            checked = checked + 1;
            if (lights !== lights_for(second)) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", lights, lights_for(second));
            end
            // Fifty cycles from one second to the next: two laps of the
            // loop. (Right after a start, 00 comes one lap before 01: the
            // test bench does not time those two.)
            if (timed && second >= 2 && ticks - changed !== 50 * PERIOD) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: %0d ticks since the last change, expected %0d",
                                           ticks - changed, 50 * PERIOD);
            end
            timed   = 1;
            changed = ticks;
            before  = led;
            second  = second + 1;
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

        // A hundred seconds and a little more: the stopwatch goes from 99
        // back to 00.
        wait (changes == 102);
        $dumpoff;

        // Hold S1 for a while: everything stops. Release it: the program
        // starts again, and the stopwatch with it, from 00.
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
        second  = 0;
        timed   = 0;
        wait (changes == 3);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, one second every %0d ticks",
                     checked, 50 * PERIOD);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
