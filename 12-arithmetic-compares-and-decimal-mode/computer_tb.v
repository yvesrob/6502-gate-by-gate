// Chapter 12, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program, stopwatch.s.
// The test bench keeps a stopwatch of its own, in ordinary numbers, and
// writes it in decimal digits to know what the program must store. It
// follows the six LEDs as well: they must show the seconds.
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

    // Where the program keeps its two bytes, as ld65 placed them.
    localparam HUNDREDTHS = 16'h0000;
    localparam SECONDS    = 16'h0001;

    // A number from 0 to 99, written as two decimal digits in one byte:
    // 47 becomes $47. That is how the program keeps its stopwatch.
    function [7:0] digits;
        input integer number;
        begin
            digits = (number / 10) * 16 + number % 10;
        end
    endfunction

    // What the bus of a 6502 shows while it runs our program, worked out
    // from the tables of cycles of the document "64doc": the address, whether
    // the processor writes, and the byte. Ten cycles to set the stopwatch to
    // zero, then the laps of the loop. Every lap has the same 25 cycles, but
    // not the same bytes: the test bench writes down each lap before it comes.
    reg [15:0]   expected_address [1:25];
    reg          expected_write   [1:25];
    reg [7:0]    expected_byte    [1:25];
    reg [8*34:1] comment          [1:25];
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
            expect_cycle(16'hC000,   0, 8'hF8, "SED");
            expect_cycle(16'hC001,   0, 8'hA9, "  the next byte, not used");
            expect_cycle(16'hC001,   0, 8'hA9, "LDA #0");
            expect_cycle(16'hC002,   0, 8'h00, "  the value");
            expect_cycle(16'hC003,   0, 8'h85, "STA hundredths");
            expect_cycle(16'hC004,   0, 8'h00, "  the address, in page zero");
            expect_cycle(HUNDREDTHS, 1, 8'h00, "  A, into the RAM");
            expect_cycle(16'hC005,   0, 8'h85, "STA seconds");
            expect_cycle(16'hC006,   0, 8'h01, "  the address, in page zero");
            expect_cycle(SECONDS,    1, 8'h00, "  A, into the RAM");
        end
    endtask

    // A lap, from what the stopwatch reads before it, in hundredths of a
    // second. Fifty more, and after 99.50 comes 00.00: the stopwatch has
    // four digits and no more.
    task plan_lap;
        input integer before;
        integer       after;
        begin
            lines = 0;
            after = (before + 50) % 10000;
            expect_cycle(16'hC007,   0, 8'h18, "CLC");
            expect_cycle(16'hC008,   0, 8'hA5, "  the next byte, not used");
            expect_cycle(16'hC008,   0, 8'hA5, "LDA hundredths");
            expect_cycle(16'hC009,   0, 8'h00, "  the address, in page zero");
            expect_cycle(HUNDREDTHS, 0, digits(before % 100), "  the hundredths");
            expect_cycle(16'hC00A,   0, 8'h69, "ADC #$50");
            expect_cycle(16'hC00B,   0, 8'h50, "  the value");
            expect_cycle(16'hC00C,   0, 8'h85, "STA hundredths");
            expect_cycle(16'hC00D,   0, 8'h00, "  the address, in page zero");
            expect_cycle(HUNDREDTHS, 1, digits(after % 100), "  A, into the RAM");
            expect_cycle(16'hC00E,   0, 8'hA5, "LDA seconds");
            expect_cycle(16'hC00F,   0, 8'h01, "  the address, in page zero");
            expect_cycle(SECONDS,    0, digits(before / 100), "  the seconds");
            expect_cycle(16'hC010,   0, 8'h69, "ADC #0");
            expect_cycle(16'hC011,   0, 8'h00, "  the value");
            expect_cycle(16'hC012,   0, 8'h85, "STA seconds");
            expect_cycle(16'hC013,   0, 8'h01, "  the address, in page zero");
            expect_cycle(SECONDS,    1, digits(after / 100), "  A, into the RAM");
            expect_cycle(16'hC014,   0, 8'h8D, "STA $8000");
            expect_cycle(16'hC015,   0, 8'h00, "  the address, low byte");
            expect_cycle(16'hC016,   0, 8'h80, "  the address, high byte");
            expect_cycle(16'h8000,   1, digits(after / 100), "  A, on its way to the LEDs");
            expect_cycle(16'hC017,   0, 8'h4C, "JMP $C007");
            expect_cycle(16'hC018,   0, 8'h07, "  the address, low byte");
            expect_cycle(16'hC019,   0, 8'hC0, "  the address, high byte");
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
            default: state_name = "?";
        endcase
    end

    integer cycle   = 0;        // cycles since the processor started
    integer place   = 0;        // where this cycle is in the list
    integer laps    = 0;        // how many times the program has stored the seconds at $8000
    integer elapsed = 0;        // the stopwatch of the test bench, in hundredths of a second
    integer checked = 0;        // cycles checked since the beginning
    integer errors  = 0;
    integer shown   = 35;       // print the cycles up to this one
    reg     asked   = 0;        // 1 once the processor has asked for its first byte
    reg     showing = 0;        // 1 while the cycles of a lap are printed
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
                if (cycle <= shown || showing) begin
                    $display("cycle %4d: %-12s %h %s %h   %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, comment[place]);
                end
                checked = checked + 1;
                if (address !== expected_address[place] || write !== expected_write[place]
                                                        || the_byte !== expected_byte[place]) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: cycle %0d is %h %s %h, expected %h %s %h",
                                               cycle, address, write ? "write" : "read ", the_byte,
                                               expected_address[place],
                                               expected_write[place] ? "write" : "read ", expected_byte[place]);
                end
                // The seconds are on their way to the LEDs: one more lap.
                if (write && address == 16'h8000) begin
                    laps    = laps + 1;
                    elapsed = (elapsed + 50) % 10000;
                    if (laps <= 4 || (laps >= 18 && laps <= 22) || laps == 79 || laps == 80
                                  || laps == 81 || laps == 199 || laps == 200 || laps == 202) begin
                        $display("lap %3d: the stopwatch reads %h.%h, the program stores %h, the LEDs show %b",
                                 laps, digits(elapsed / 100), digits(elapsed % 100), data_out, leds);
                    end
                end
                // The end of the list: write down the next lap.
                if (place == lines) begin
                    plan_lap(elapsed);
                    place = 0;
                    // Print the lap in which the seconds go from 09 to 10,
                    // and keep it in the waveform as well.
                    if (showing) $dumpoff;
                    showing = (elapsed == 950);
                    if (showing) begin
                        $display("...");
                        $dumpon;
                    end
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
    // laps it is waiting for never come, it gives up after 100,000 ticks.
    initial begin
        #1000000;
        $display("FAIL: computer, still waiting after 100,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Thirty-five cycles to look at: the stopwatch set to zero, then the
        // first lap.
        wait (cycle == shown);
        @(posedge clk);
        $dumpoff;

        // Then 202 laps, 101 seconds: the stopwatch goes past 99.50 and
        // starts again from 00.00.
        wait (laps == 202);

        // A reset starts the program again. It comes at the worst moment:
        // the processor has just begun to store the seconds at $8000.
        // (The test bench moves reset just after a tick, as a flip-flop would.)
        wait (place == lines - 4);
        $display("reset");
        @(posedge clk);
        #1 reset = 1;
        asked   = 0;
        cycle   = 0;
        place   = 0;
        laps    = 0;
        elapsed = 0;
        shown   = 10;
        plan_start;
        repeat (3) @(posedge clk);
        #1 reset = 0;
        wait (laps == 2);
        @(posedge clk);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, and a stopwatch that counts in decimal",
                     checked);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
