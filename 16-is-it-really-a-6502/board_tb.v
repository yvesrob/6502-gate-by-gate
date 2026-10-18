// Chapter 16, test bench for board.v: what goes onto the board, pins and
// all, at its real speed, one cycle of the processor every two ticks. The
// six pins of the LEDs show the count of the times the test went well,
// upside down (an LED is lit when its pin is LOW): no LED at first. Button S2
// bounces, as a real button does, and asks for NMI: the test did not expect
// it, and must stop in its trap for NMI, at $379D. Button S1 must start
// everything again: the count back to 0, the copy, the test.
//   vvp board_tb.vvp          the buttons, in about 40 milliseconds of the board
//   vvp board_tb.vvp +full    no button: the whole test, until the LEDs show 1
//                             (seven seconds of the board, a quarter of an hour here)
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire [5:0] led;

    top dut (
        .clk  (clk),
        .btn1 (btn1),
        .btn2 (btn2),
        .led  (led)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // In the chip the RAM starts at zero; in the simulator it starts unknown.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.our_computer.the_ram.cells[n] = 8'h00;
        end
    end

    localparam TEST     = 16'h0400;     // the first instruction of the test
    localparam NMI_TRAP = 16'h379D;     // where it stops when an NMI comes

    // What the test bench watches, inside the computer: the bus, and the
    // steps of the timer.
    wire [15:0] address;
    wire        opcode;
    assign address = dut.our_computer.address;
    assign opcode  = dut.step & (dut.our_computer.processor.state == 1) & ~dut.our_computer.processor.asking;

    integer ticks       = 0;
    integer last_step   = 0;
    integer gaps        = 0;    // steps that did not come two ticks after the one before
    integer begins      = 0;    // how many times the test has begun, at $0400
    integer began_at    = 0;
    integer nmis        = 0;    // NMIs taken: the vector at $FFFA read
    integer in_trap     = 0;    // instructions in a row at $379D
    integer errors      = 0;
    reg [5:0] before    = 6'b111111;
    integer when_one    = 0;    // the tick at which the LEDs first show 1

    always @(posedge clk) begin
        ticks = ticks + 1;
        if (dut.step) begin
            if (last_step != 0 && ticks - last_step != 2) gaps = gaps + 1;
            last_step = ticks;
        end
    end

    always @(negedge clk) begin
        if (led !== before) begin
            $display("tick %9d: the pins show %b, the LEDs show %b", ticks, led, ~led);
            before = led;
            if (led == 6'b111110 && when_one == 0) when_one = ticks;
        end
        if (opcode && ~dut.reset) begin
            if (address == TEST) begin
                begins   = begins + 1;
                began_at = ticks;
                $display("tick %9d: the copy is done, the test begins at %h", ticks, address);
            end
            in_trap = (address == NMI_TRAP) ? in_trap + 1 : 0;
        end
        if (dut.step && address == 16'hFFFA && ~dut.our_computer.write) begin
            nmis = nmis + 1;
        end
    end

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
        #2_100_000_000;
        $display("FAIL: board, still waiting after 210 million ticks");
        $fatal;
    end

    initial begin
        if ($test$plusargs("full")) begin
            // The whole test, from switching on, until the LEDs show 1.
            wait (led == 6'b111110);
            @(negedge clk);
            @(negedge clk);
            if (gaps != 0) errors = errors + 1;
            if (errors == 0) begin
                $display("PASS: board, the LEDs show 1 after %0d ticks, %0.3f seconds of the board, one cycle every two ticks",
                         when_one, when_one / 27_000_000.0);
                $finish;
            end else begin
                $display("FAIL: board, %0d error(s)", errors);
                $fatal;
            end
        end

        // Switched on: the copy, then the test.
        wait (begins == 1);
        if (led !== 6'b111111) begin
            errors = errors + 1;
            $display("wrong: the pins show %b, expected 111111: no LED", led);
        end

        // S2, a hundred thousand ticks later, with a bounce of 400 ticks:
        // the contact changes every 70 ticks. Held 2,000 ticks, and let go
        // with a bounce too.
        repeat (100_000) @(posedge clk);
        #1;
        $display("tick %9d: S2 pressed, with a bounce of 400 ticks", ticks);
        bouncing(1, 400, 70);
        repeat (2_000) @(posedge clk);
        #1;
        bouncing(0, 400, 70);
        $display("tick %9d: S2 let go", ticks);
        repeat (2_000) @(posedge clk);
        if (in_trap < 100) begin
            errors = errors + 1;
            $display("wrong: the processor is not in the trap for NMI");
        end else begin
            $display("tick %9d: %0d NMIs, one each time the bouncing contact closed; the test has stopped in its trap at %h",
                     ticks, nmis, NMI_TRAP);
        end

        // S1, held 5,000 ticks: nothing moves. Let go: the reset, the count
        // back to 0, the copy, and the test again.
        #1 btn1 = 1;
        $display("tick %9d: S1 pressed", ticks);
        repeat (5_000) @(posedge clk);
        #1 btn1 = 0;
        $display("tick %9d: S1 let go", ticks);
        wait (begins == 2);
        repeat (1_000) @(posedge clk);
        @(negedge clk);
        if (led !== 6'b111111) begin
            errors = errors + 1;
            $display("wrong: the pins show %b, expected 111111", led);
        end
        if (in_trap != 0) errors = errors + 1;
        if (gaps != 0) begin
            errors = errors + 1;
            $display("wrong: %0d steps did not come two ticks after the one before", gaps);
        end
        if (errors == 0) begin
            $display("PASS: board, one cycle every two ticks; S2 stops the test in its trap; S1 starts it again");
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;
        end
    end
endmodule
