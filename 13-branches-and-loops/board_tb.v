// Chapter 13, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must show the Collatz sequence from 7 down
// to 1, upside down (an LED is lit when its pin is LOW), each for 67 cycles
// if it is even and 79 if it is odd, and then nothing more must move. Button
// S1 must freeze the LEDs, and start the program again from 7.
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
    integer number  = 7;        // the number the next change must show
    integer shown   = 0;        // the number the LEDs show now
    reg [5:0] before = 6'b111111;   // all the pins HIGH: no LED is lit
    reg [5:0] lights;
    reg       timed  = 0;           // is there a change before this one to measure from?

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    // Each time the pins change, they must show the next number. After an
    // even number the program needs 67 cycles to show the next one, after an
    // odd number 79: the branches do not go the same way.
    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            lights  = ~led;         // lit means LOW: turn the pins over to read the LEDs
            $display("tick %5d: the pins show %b, the LEDs show %b (%0d)", ticks, led, lights, number);
            checked = checked + 1;
            if (lights !== number) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", lights, number[5:0]);
            end
            if (timed && ticks - changed !== ((shown % 2 == 0) ? 67 : 79) * PERIOD) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: %0d ticks since the last change, expected %0d",
                                           ticks - changed, ((shown % 2 == 0) ? 67 : 79) * PERIOD);
            end
            timed   = 1;
            changed = ticks;
            before  = led;
            shown   = number;
            number  = (number == 1) ? 0 : (number % 2 == 0) ? number / 2 : 3 * number + 1;
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

        // Six numbers, up to 52. Then hold S1 for a while: everything stops.
        wait (changes == 6);
        $dumpoff;
        @(negedge clk);
        btn1 = 1;
        repeat (200) @(negedge clk);
        if (led !== before) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved while S1 was held down");
        end
        // Release it: the program starts again, from 7.
        btn1 = 0;
        $display("S1 held for 200 ticks, then released");
        number = 7;
        timed  = 0;

        // The seventeen numbers, from 7 down to 1. Then the loop stops by
        // itself, and the LEDs must stay as they are.
        wait (changes == 6 + 17);
        repeat (1000) @(negedge clk);
        if (led !== before) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved after 1");
        end
        $display("1000 ticks later, the LEDs still show %b", ~led);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, the numbers from 7 down to 1, and then nothing",
                     checked);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
