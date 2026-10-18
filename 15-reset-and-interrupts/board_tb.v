// Chapter 15, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must show the light of walk.s, upside down
// (an LED is lit when its pin is LOW), one LED further every 49 cycles, and
// back to LED 1 after 53. Button S2 bounces, as a real button does. Pressed
// with a bounce shorter than a cycle, it must light the six LEDs once, for 46
// cycles, and the light must go on from where it was. Pressed again while
// the six LEDs are lit, it must keep them lit 90 cycles longer. Button S1
// must freeze the LEDs, and start the program again from LED 1.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire [5:0] led;

    // On the board one cycle of the processor lasts 540,000 ticks, and the
    // simulator would take a long time. Here a cycle lasts 50 ticks: long
    // enough for a bounce of the button to be over within one cycle.
    parameter PERIOD = 50;

    top #(.PERIOD(PERIOD)) dut (
        .clk  (clk),
        .btn1 (btn1),
        .btn2 (btn2),
        .led  (led)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer ticks   = 0;        // ticks of the clock since the beginning
    integer changes = 0;        // how many times the pins have changed
    integer when    = 0;        // the tick of the last change
    integer errors  = 0;
    integer checked = 0;
    reg [5:0] before = 6'b111111;   // all the pins HIGH: no LED is lit
    reg [5:0] lights = 0;           // what the LEDs show

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            lights  = ~led;         // lit means LOW: turn the pins over to read the LEDs
            when    = ticks;
            before  = led;
            $display("tick %6d: the pins show %b, the LEDs show %b", ticks, led, lights);
        end
    end

    // Wait for the next change of the pins. It must show this pattern, and,
    // unless cycles is -1, come this many cycles after the change before.
    integer seen = 0;
    integer last = 0;
    task next_change;
        input [5:0]   pattern;
        input integer cycles;
        begin
            wait (changes > seen);
            seen    = seen + 1;
            checked = checked + 1;
            if (lights !== pattern) begin
                errors = errors + 1;
                $display("wrong: the LEDs show %b, expected %b", lights, pattern);
            end
            if (cycles >= 0 && when - last !== cycles * PERIOD) begin
                errors = errors + 1;
                $display("wrong: %0d ticks since the change before, expected %0d", when - last,
                         cycles * PERIOD);
            end
            last = when;
        end
    endtask

    // S2 goes to level, with a bounce: for a number of ticks (bounce), the
    // contact changes every few ticks (every), then it stays at level.
    task bouncing;
        input         level;
        input integer bounce;
        input integer every;
        integer t;
        begin
            for (t = 0; t < bounce; t = t + every) begin
                btn2 = ~btn2;
                repeat (every) @(posedge clk);
                #1;
            end
            btn2 = level;
        end
    endtask

    // A test bench that waits for a processor needs a time limit.
    initial begin
        #2000000;
        $display("FAIL: board, still waiting after 200,000 ticks");
        $fatal;
    end

    integer at;
    initial begin
        $dumpfile("board_tb.vcd");
        $dumpvars(0, board_tb);

        // Switched on: the reset, then the light at LED 1, 2, 3.
        next_change(6'b000001, -1);
        next_change(6'b000010, 49);
        next_change(6'b000100, 49);
        $dumpoff;

        // S2, pressed 20 cycles later, with a bounce of 40 ticks: the contact
        // changes every 7 ticks. The processor looks at NMI once a cycle, so
        // it sees one press. Held for 30 cycles, and let go with a bounce too.
        repeat (20 * PERIOD) @(posedge clk);
        #1;
        $display("S2 pressed, with a bounce of 40 ticks");
        bouncing(1, 40, 7);
        repeat (30 * PERIOD) @(posedge clk);
        #1;
        $display("S2 let go, with a bounce of 40 ticks");
        bouncing(0, 40, 7);
        // The six LEDs, for 46 cycles; then LED 3 again, where the light was.
        // The step of LED 3 lasts 49 cycles, and 90 more for the NMI.
        at = last;
        next_change(6'b111111, -1);
        next_change(6'b000100, 46);
        next_change(6'b001000, -1);
        if (last - at !== (49 + 90) * PERIOD) begin
            errors = errors + 1;
            $display("wrong: LED 3 stayed %0d ticks, expected %0d", last - at, (49 + 90) * PERIOD);
        end else begin
            $display("LED 3 stayed 49 cycles, and 90 for the NMI: one press seen");
        end

        // S2 again, at LED 5, and once more 40 cycles later, while the six
        // LEDs are lit: NMI cannot be refused, and a second handler runs
        // inside the first. The six LEDs stay lit for 46 cycles, and 90 more.
        next_change(6'b010000, 49);
        repeat (10 * PERIOD) @(posedge clk);
        #1;
        $display("S2 pressed");
        bouncing(1, 40, 7);
        repeat (5 * PERIOD) @(posedge clk);
        #1;
        bouncing(0, 40, 7);
        repeat (35 * PERIOD) @(posedge clk);
        #1;
        $display("S2 pressed again, while the six LEDs are lit");
        bouncing(1, 40, 7);
        repeat (5 * PERIOD) @(posedge clk);
        #1;
        bouncing(0, 40, 7);
        at = last;
        next_change(6'b111111, -1);
        next_change(6'b010000, 46 + 90);
        next_change(6'b100000, -1);
        if (last - at !== (49 + 2 * 90) * PERIOD) begin
            errors = errors + 1;
            $display("wrong: LED 5 stayed %0d ticks, expected %0d", last - at, (49 + 2 * 90) * PERIOD);
        end else begin
            $display("LED 5 stayed 49 cycles, and 2 x 90 for two NMIs, one inside the other");
        end

        // S1, held for 60 cycles: nothing moves. Then let go: the reset, and
        // the light starts again from LED 1.
        next_change(6'b000001, 53);
        repeat (10 * PERIOD) @(posedge clk);
        #1 btn1 = 1;
        $display("S1 held for 60 cycles");
        repeat (60 * PERIOD) @(posedge clk);
        if (changes != seen) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved while S1 was held down");
        end
        #1 btn1 = 0;
        $display("S1 let go");
        next_change(6'b000010, -1);     // LED 1 was lit already: the first change is to LED 2
        next_change(6'b000100, 49);
        next_change(6'b001000, 49);
        next_change(6'b010000, 49);
        next_change(6'b100000, 49);
        next_change(6'b000001, 53);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, the light, S2 with its bounces, and S1", checked);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
