// Chapter 13, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program, collatz.s.
// The test bench works out the Collatz sequence on its own, in ordinary
// numbers, to know what the program must store, which way each branch must
// go, and when the loop must stop. It follows the six LEDs as well: they
// must show the numbers.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         reset = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;

    // The timer from chapter 3 says when the processor moves. In the test
    // bench its period is a parameter: 2 is as fast as the bus allows.
    parameter PERIOD = 2;

    timer #(.PERIOD(PERIOD)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // Where the program keeps its number, as ld65 placed it.
    localparam N = 16'h0000;

    // What the bus of a 6502 shows while it runs our program, worked out
    // from the tables of cycles of the document "64doc": the address, whether
    // the processor writes, and the byte. Two cycles for the first number,
    // then one step for each number: show it, wait, decide. The steps are not
    // all the same, so the test bench writes down each one before it comes.
    reg [15:0]   expected_address [1:90];
    reg          expected_write   [1:90];
    reg [7:0]    expected_byte    [1:90];
    reg [8*34:1] comment          [1:90];
    integer      lines = 0;         // how many lines the list holds now

    task expect_cycle;
        input [15:0]   the_address;
        input          the_write;
        input [7:0]    the_byte;
        input [8*34:1] the_comment;
        begin
            lines                   = lines + 1;
            expected_address[lines] = the_address;
            expected_write[lines]   = the_write;
            expected_byte[lines]    = the_byte;
            comment[lines]          = the_comment;
        end
    endtask

    task plan_start;
        begin
            lines = 0;
            //           address    write  byte
            expect_cycle(16'hC000,   0, 8'hA9, "LDA #7");
            expect_cycle(16'hC001,   0, 8'h07, "  the value");
        end
    endtask

    // One step, from the number it shows. The branches are where two steps
    // differ: the test bench decides which way each one goes.
    task plan_step;
        input integer n;
        integer       lap;
        begin
            lines = 0;
            expect_cycle(16'hC002,   0, 8'h85, "STA n");
            expect_cycle(16'hC003,   0, 8'h00, "  the address, in page zero");
            expect_cycle(N,          1, n,     "  A, into the RAM");
            expect_cycle(16'hC004,   0, 8'h8D, "STA $8000");
            expect_cycle(16'hC005,   0, 8'h00, "  the address, low byte");
            expect_cycle(16'hC006,   0, 8'h80, "  the address, high byte");
            expect_cycle(16'h8000,   1, n,     "  A, on its way to the LEDs");
            expect_cycle(16'hC007,   0, 8'hA2, "LDX #10");
            expect_cycle(16'hC008,   0, 8'h0A, "  the value");
            // The wait: ten laps. X goes from 10 down to 0, and the branch
            // is taken nine times, while X is not 0 yet.
            for (lap = 1; lap <= 10; lap = lap + 1) begin
                expect_cycle(16'hC009, 0, 8'hCA, "DEX");
                expect_cycle(16'hC00A, 0, 8'hD0, "  the next byte, not used");
                expect_cycle(16'hC00A, 0, 8'hD0, "BNE $C009");
                expect_cycle(16'hC00B, 0, 8'hFD, "  how far: FD, back 3");
                if (lap < 10) begin
                    expect_cycle(16'hC00C, 0, 8'hC9, "  the next opcode, for nothing");
                end
            end
            expect_cycle(16'hC00C,   0, 8'hC9, "CMP #1");
            expect_cycle(16'hC00D,   0, 8'h01, "  the value");
            expect_cycle(16'hC00E,   0, 8'hF0, "BEQ $C01C");
            expect_cycle(16'hC00F,   0, 8'h0C, "  how far: 0C, forward 12");
            if (n == 1) begin
                // The end: the branch is taken, to done.
                expect_cycle(16'hC010, 0, 8'h4A, "  the next opcode, for nothing");
            end else begin
                expect_cycle(16'hC010, 0, 8'h4A, "LSR A");
                expect_cycle(16'hC011, 0, 8'h90, "  the next byte, not used");
                expect_cycle(16'hC011, 0, 8'h90, "BCC $C002");
                expect_cycle(16'hC012, 0, 8'hEF, "  how far: EF, back 17");
                if (n % 2 == 0) begin
                    // Even: the branch is taken, and A holds n / 2.
                    expect_cycle(16'hC013, 0, 8'hA5, "  the next opcode, for nothing");
                end else begin
                    // Odd: on to 3n + 1.
                    expect_cycle(16'hC013, 0, 8'hA5, "LDA n");
                    expect_cycle(16'hC014, 0, 8'h00, "  the address, in page zero");
                    expect_cycle(N,        0, n,     "  n");
                    expect_cycle(16'hC015, 0, 8'h0A, "ASL A");
                    expect_cycle(16'hC016, 0, 8'h38, "  the next byte, not used");
                    expect_cycle(16'hC016, 0, 8'h38, "SEC");
                    expect_cycle(16'hC017, 0, 8'h65, "  the next byte, not used");
                    expect_cycle(16'hC017, 0, 8'h65, "ADC n");
                    expect_cycle(16'hC018, 0, 8'h00, "  the address, in page zero");
                    expect_cycle(N,        0, n,     "  n");
                    expect_cycle(16'hC019, 0, 8'h4C, "JMP $C002");
                    expect_cycle(16'hC01A, 0, 8'h02, "  the address, low byte");
                    expect_cycle(16'hC01B, 0, 8'hC0, "  the address, high byte");
                end
            end
        end
    endtask

    // After the end: the program jumps to itself, forever.
    task plan_done;
        begin
            lines = 0;
            expect_cycle(16'hC01C,   0, 8'h4C, "JMP $C01C");
            expect_cycle(16'hC01D,   0, 8'h1C, "  the address, low byte");
            expect_cycle(16'hC01E,   0, 8'hC0, "  the address, high byte");
        end
    endtask

    // The state of the processor, as a name to print. The numbers are those
    // of cpu.v.
    reg [8*12:1] state_name;
    always @(*) begin
        case (dut.processor.state)
            0:       state_name = "STARTING";
            1:       state_name = "OPCODE";
            2:       state_name = "OPERAND";
            3:       state_name = "HIGH";
            4:       state_name = "STORE";
            5:       state_name = "DATA";
            6:       state_name = "INDEX";
            7:       state_name = "FIX";
            8:       state_name = "POINTER_LOW";
            9:       state_name = "POINTER_HIGH";
            10:      state_name = "MODIFY";
            11:      state_name = "WRITE_BACK";
            12:      state_name = "BRANCH";
            13:      state_name = "BRANCH_FIX";
            default: state_name = "?";
        endcase
    end

    integer cycle   = 0;        // cycles since the processor started
    integer place   = 0;        // where this cycle is in the list
    integer number  = 7;        // the number of the step under way, worked out by the test bench
    integer numbers = 0;        // how many numbers the program has stored at $8000
    integer stored  = 0;        // the cycle of the last of them
    integer ended   = 0;        // 1 once the loop has stopped
    integer after   = 0;        // cycles checked since then
    integer checked = 0;        // cycles checked since the beginning
    integer errors  = 0;
    integer run     = 1;        // 1 before the reset, 2 after it
    reg     asked   = 0;        // 1 once the processor has asked for its first byte
    reg [7:0] the_byte;

    initial plan_start;

    // We look at the bus half-way between two ticks, when nothing moves. A
    // step is coming at the next tick: this is the end of a cycle.
    always @(negedge clk) begin
        if (step & ~reset) begin
            if (asked) begin
                cycle    = cycle + 1;
                place    = place + 1;
                the_byte = write ? data_out : data_in;
                checked  = checked + 1;
                if (ended) after = after + 1;
                // Print the first 26 cycles; from the last lap of the wait on,
                // the first two steps, an odd number and an even one; after
                // the reset, the first cycles and the end.
                if ((run == 1 && (cycle <= 26 || (place >= 55 && numbers <= 2)))
                 || (run == 2 && (cycle <= 4 || (place >= 55 && number == 1 && !ended) || (ended && after <= 3)))) begin
                    $display("cycle %4d: %-12s %h %s %h   %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, comment[place]);
                end
                if (address !== expected_address[place] || write !== expected_write[place]
                                                        || the_byte !== expected_byte[place]) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: cycle %0d is %h %s %h, expected %h %s %h",
                                               cycle, address, write ? "write" : "read ", the_byte,
                                               expected_address[place],
                                               expected_write[place] ? "write" : "read ", expected_byte[place]);
                end
                // A number is on its way to the LEDs.
                if (write && address == 16'h8000) begin
                    numbers = numbers + 1;
                    if (numbers == 1) begin
                        $display("number %2d: %2d, at cycle %0d", numbers, data_out, cycle);
                    end else begin
                        $display("number %2d: %2d, %0d cycles after the one before", numbers, data_out,
                                 cycle - stored);
                    end
                    stored = cycle;
                end
                // The end of the list: write down what comes next.
                if (place == lines) begin
                    if (lines == 2) begin
                        plan_step(number);          // after LDA #7, the first step
                    end else if (ended) begin
                        plan_done;
                    end else if (number == 1) begin
                        plan_done;                  // the loop has stopped
                        ended = 1;
                        $display("...");
                    end else begin
                        number = (number % 2 == 0) ? number / 2 : 3 * number + 1;
                        plan_step(number);
                    end
                    place = 0;
                end
            end
            // The very first step only asks for the first byte.
            asked = 1;
        end
    end

    // The LEDs. At every tick the test bench does what the computer should
    // do: if the processor is writing at $8000, the six low bits of the byte
    // are what the LEDs must show from then on. They must show nothing else.
    reg [5:0] expected_leds = 0;
    always @(posedge clk) begin
        if (write & (address == 16'h8000)) begin
            expected_leds = data_out[5:0];
        end
    end
    always @(negedge clk) begin
        if (leds !== expected_leds) begin
            errors = errors + 1;
            if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", leds, expected_leds);
        end
    end

    // A test bench that waits for a processor needs a time limit. If the
    // numbers it is waiting for never come, it gives up after 20,000 ticks.
    initial begin
        #200000;
        $display("FAIL: computer, still waiting after 20,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Keep the waveform small: the first step only.
        wait (numbers == 2);
        $dumpoff;

        // A reset starts the program again. It comes at the worst moment:
        // the processor has just begun to store the fourth number at $8000.
        // (The test bench moves reset just after a tick, as a flip-flop would.)
        wait (numbers == 3 && place == 6);
        $display("reset");
        @(posedge clk);
        #1 reset = 1;
        asked   = 0;
        cycle   = 0;
        place   = 0;
        number  = 7;
        numbers = 0;
        run     = 2;
        plan_start;
        repeat (3) @(posedge clk);
        #1 reset = 0;

        // Then the whole run: seventeen numbers, from 7 down to 1, and the
        // loop that stops. After the end, nothing more reaches the LEDs.
        wait (ended && after == 60);
        @(negedge clk);
        if (numbers != 17) begin
            errors = errors + 1;
            $display("wrong: %0d numbers stored at $8000, expected 17", numbers);
        end

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, 17 numbers, and a loop that stops by itself",
                     checked);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
