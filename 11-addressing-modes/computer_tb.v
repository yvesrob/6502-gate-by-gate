// Chapter 11, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program, sweep.s. It
// follows the six LEDs as well: they must show the bytes of the table, one
// after the other.
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

    // The eight steps of the light, as sweep.s writes them, and the twelve
    // bytes of the program, as the listing shows them.
    reg [7:0] steps [0:7];
    reg [7:0] code  [0:11];
    initial begin
        steps[0] = 8'b000011;  steps[1] = 8'b000110;  steps[2] = 8'b001100;  steps[3] = 8'b011000;
        steps[4] = 8'b110000;  steps[5] = 8'b011000;  steps[6] = 8'b001100;  steps[7] = 8'b000110;
        code[0] = 8'hA2;  code[1] = 8'h00;                                      // LDX #0
        code[2] = 8'hBD;  code[3] = 8'h0C;  code[4]  = 8'hC0;                   // LDA $C00C,X
        code[5] = 8'h8D;  code[6] = 8'h00;  code[7]  = 8'h80;                   // STA $8000
        code[8] = 8'hE8;                                                        // INX
        code[9] = 8'h4C;  code[10] = 8'h02; code[11] = 8'hC0;                   // JMP $C002
    end

    // What the bus of a 6502 shows while it runs our program, worked out
    // from the tables of cycles of the document "64doc": the address, whether
    // the processor writes, and the byte. Two cycles for LDX #0, then the
    // laps of the loop. A lap depends on X: it reads the table at $C00C + X,
    // and when that sum goes past the end of the page, a 6502 takes one more
    // cycle. So the test bench writes down each lap before it comes.
    reg [15:0]   expected_address [1:14];
    reg          expected_write   [1:14];
    reg [7:0]    expected_byte    [1:14];
    reg [8*34:1] comment          [1:14];
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
            //           address  write  byte
            expect_cycle(16'hC000, 0, 8'hA2, "LDX #0");
            expect_cycle(16'hC001, 0, 8'h00, "  the value");
        end
    endtask

    task plan_lap;
        input [7:0] x;
        reg   [8:0] sum;        // the low byte of the table's address, plus X: nine bits
        reg   [7:0] light;      // the byte of the table at X
        begin
            lines = 0;
            sum   = 9'h00C + x;
            light = steps[x % 8];
            expect_cycle(16'hC002, 0, 8'hBD, "LDA table,X");
            expect_cycle(16'hC003, 0, 8'h0C, "  the address, low byte");
            expect_cycle(16'hC004, 0, 8'hC0, "  the address, high byte");
            if (sum[8] == 0) begin
                expect_cycle({8'hC0, sum[7:0]}, 0, light, "  the byte of the table");
            end else begin
                // Past the end of the page: a read on the old page first.
                expect_cycle({8'hC0, sum[7:0]}, 0, code[sum[7:0]], "  on the old page, not used");
                expect_cycle({8'hC1, sum[7:0]}, 0, light,          "  the byte of the table");
            end
            expect_cycle(16'hC005, 0, 8'h8D, "STA $8000");
            expect_cycle(16'hC006, 0, 8'h00, "  the address, low byte");
            expect_cycle(16'hC007, 0, 8'h80, "  the address, high byte");
            expect_cycle(16'h8000, 1, light, "  A, on its way to the LEDs");
            expect_cycle(16'hC008, 0, 8'hE8, "INX");
            expect_cycle(16'hC009, 0, 8'h4C, "  the next byte, not used");
            expect_cycle(16'hC009, 0, 8'h4C, "JMP $C002");
            expect_cycle(16'hC00A, 0, 8'h02, "  the address, low byte");
            expect_cycle(16'hC00B, 0, 8'hC0, "  the address, high byte");
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
    integer laps    = 0;        // how many times the program has stored A
    integer longer  = 0;        // laps that took one more cycle
    integer checked = 0;        // cycles checked since the beginning
    integer errors  = 0;
    integer shown   = 28;       // print the cycles up to this one
    reg     asked   = 0;        // 1 once the processor has asked for its first byte
    reg     looping = 0;        // 1 once LDX #0 is behind us
    reg     showing = 0;        // 1 while the cycles of a lap are printed
    reg [7:0] x     = 0;        // what X holds in a 6502 that runs our program
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
                // A byte has been stored: one more lap.
                if (write) begin
                    laps = laps + 1;
                    if (laps <= 9 || laps == 244 || laps == 245 || laps == 256 || laps == 257
                                  || laps == 600) begin
                        $display("lap %3d: X = %3d, the program stores %h, the LEDs show %b",
                                 laps, x, data_out, leds);
                    end
                end
                // The end of the list: write down the next lap.
                if (place == lines) begin
                    if (looping) x = x + 1;
                    looping = 1;
                    plan_lap(x);
                    place = 0;
                    if (lines == 14) longer = longer + 1;
                    // Print the first lap that takes one more cycle, and keep
                    // it in the waveform as well.
                    if (showing) $dumpoff;
                    showing = (lines == 14) && (longer == 1);
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

        // Twenty-eight cycles to look at: LDX #0, then two laps of the loop.
        wait (cycle == shown);
        @(posedge clk);
        $dumpoff;

        // Then 600 laps: X goes past 255 twice, and the lap that crosses a
        // page comes twelve times each time round.
        wait (laps == 600);

        // A reset starts the program again. It comes at the worst moment:
        // the processor has just begun to store a byte.
        // (The test bench moves reset just after a tick, as a flip-flop would.)
        wait (place == lines - 6);
        $display("reset");
        @(posedge clk);
        #1 reset = 1;
        asked   = 0;
        cycle   = 0;
        place   = 0;
        laps    = 0;
        looping = 0;
        x       = 0;
        shown   = 10;
        plan_start;
        repeat (3) @(posedge clk);
        #1 reset = 0;
        wait (laps == 1);
        @(posedge clk);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, %0d laps one cycle longer, and LEDs that follow the table",
                     checked, longer);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
