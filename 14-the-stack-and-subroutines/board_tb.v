// Chapter 14, test bench for board.v: what goes onto the board, pins and
// all. The six pins of the LEDs must show the bar of deeper.s, upside down
// (an LED is lit when its pin is LOW): one LED more at each call, from the
// USB-C end, up to six, then one less at each return, down to none, and
// again. Each pattern must stay as many cycles as the program takes to reach
// the next one. Button S1 must freeze the LEDs, and start the program again.
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

    // One round of the bar, from all off, and the cycles from each pattern
    // to the next: 47 from none to one LED, 54 for each call that goes one
    // deeper, 52 for the first return, 47 for each of the others, and 48
    // from one LED back to none.
    reg [5:0] pattern [0:11];
    integer   after   [0:11];
    initial begin
        pattern[0]  = 6'b000000;  after[0]  = 47;
        pattern[1]  = 6'b000001;  after[1]  = 54;
        pattern[2]  = 6'b000011;  after[2]  = 54;
        pattern[3]  = 6'b000111;  after[3]  = 54;
        pattern[4]  = 6'b001111;  after[4]  = 54;
        pattern[5]  = 6'b011111;  after[5]  = 54;
        pattern[6]  = 6'b111111;  after[6]  = 52;
        pattern[7]  = 6'b011111;  after[7]  = 47;
        pattern[8]  = 6'b001111;  after[8]  = 47;
        pattern[9]  = 6'b000111;  after[9]  = 47;
        pattern[10] = 6'b000011;  after[10] = 47;
        pattern[11] = 6'b000001;  after[11] = 48;
    end

    integer ticks   = 0;        // ticks of the clock since the beginning
    integer changed = 0;        // the tick of the last change
    integer changes = 0;
    integer checked = 0;
    integer errors  = 0;
    integer next    = 1;        // where the next change is in the round: the LEDs
                                // start off, so the first change is to one LED
    reg [5:0] before = 6'b111111;   // all the pins HIGH: no LED is lit
    reg [5:0] lights;
    reg       timed  = 0;           // is there a change before this one to measure from?

    always @(posedge clk) begin
        ticks = ticks + 1;
    end

    // Each time the pins change, they must show the next pattern of the round,
    // and the time since the change before must be what the program takes.
    always @(negedge clk) begin
        if (led !== before) begin
            changes = changes + 1;
            lights  = ~led;         // lit means LOW: turn the pins over to read the LEDs
            $display("tick %5d: the pins show %b, the LEDs show %b", ticks, led, lights);
            checked = checked + 1;
            if (lights !== pattern[next]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", lights, pattern[next]);
            end
            if (timed && ticks - changed !== after[(next + 11) % 12] * PERIOD) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: %0d ticks since the last change, expected %0d",
                                           ticks - changed, after[(next + 11) % 12] * PERIOD);
            end
            timed   = 1;
            changed = ticks;
            before  = led;
            next    = (next + 1) % 12;
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

        // A round and two patterns more. Then hold S1 for a while: everything stops.
        wait (changes == 14);
        $dumpoff;
        @(negedge clk);
        btn1 = 1;
        repeat (200) @(negedge clk);
        if (led !== before) begin
            errors = errors + 1;
            $display("wrong: the LEDs moved while S1 was held down");
        end
        // Release it: the program starts again, and its first pattern is all off.
        btn1 = 0;
        $display("S1 held for 200 ticks, then released");
        next  = 0;
        timed = 0;

        // A whole round from the start.
        wait (changes == 14 + 12);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: board, %0d changes of the LEDs, the bar up and down, and S1", checked);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
