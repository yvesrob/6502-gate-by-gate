// Chapter 14, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program, deeper.s.
// The test bench follows the calls on its own: it keeps its own S, knows
// which address each JSR pushes and which pattern each PHA pushes, and so
// knows what each RTS and each PLA must find on the stack. It follows the
// six LEDs as well: they must show the patterns.
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

    // In the chip the RAM starts at zero (we measured it in chapter 8); in
    // the simulator it starts unknown. The test bench does what the chip
    // does, so that a read for nothing finds what it would find on the board.
    // It keeps a copy of page 1, the stack, as the processor writes it.
    reg [7:0] stack [0:255];
    integer   n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.the_ram.cells[n] = 8'h00;
        end
        for (n = 0; n < 256; n = n + 1) begin
            stack[n] = 8'h00;
        end
    end

    // What the bus of a 6502 shows while it runs our program, worked out
    // from the tables of cycles of the document "64doc": the address, whether
    // the processor writes, and the byte. A cycle that reads the stack for
    // nothing finds whatever is there: from_stack says so, and the byte is
    // looked up in the copy of page 1 when the cycle comes.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:700];
    reg          expected_write   [1:700];
    reg [7:0]    expected_byte    [1:700];
    reg          from_stack       [1:700];
    reg          shown            [1:700];  // 1: print this cycle
    reg [8*34:1] comment          [1:700];
    integer      lines    = 0;      // how many lines the list holds now
    integer      printing = 0;      // 1: the lines written down now will be printed
    integer      s        = 0;      // S, as the test bench works it out
    integer      deepest  = 0;      // the line where the stack is at its deepest
    integer      sixth    = 0;      // the line where the fifth call starts to call the sixth

    task bus;
        input [15:0]   the_address;
        input          the_write;
        input [7:0]    the_byte;
        input [8*34:1] the_comment;
        begin
            lines                   = lines + 1;
            expected_address[lines] = the_address;
            expected_write[lines]   = the_write;
            expected_byte[lines]    = the_byte;
            from_stack[lines]       = 0;
            shown[lines]            = printing;
            comment[lines]          = the_comment;
        end
    endtask

    task bus_stack;
        input [8*34:1] the_comment;
        begin
            bus({8'h01, s[7:0]}, R, 8'h00, the_comment);
            from_stack[lines] = 1;
        end
    endtask

    // JSR, at the address at, to target: six cycles.
    task call;
        input [15:0]   at;
        input [15:0]   target;
        input [8*34:1] the_name;
        reg   [15:0]   last;            // the last byte of the JSR: the address it pushes
        begin
            last = at + 16'd2;
            bus(at,              R, 8'h20,        the_name);
            bus(at + 16'd1,      R, target[7:0],  "  the address, low byte");
            bus_stack(                            "  the stack, read for nothing");
            bus({8'h01, s[7:0]}, W, last[15:8],   "  pc, high byte, pushed");
            s = (s - 1) & 255;
            bus({8'h01, s[7:0]}, W, last[7:0],    "  pc, low byte, pushed");
            s = (s - 1) & 255;
            bus(last,            R, target[15:8], "  the address, high byte");
        end
    endtask

    // RTS, at the address at, back to the JSR whose last byte is at last:
    // six cycles. next is the byte that follows the RTS.
    task come_back;
        input [15:0] at;
        input [7:0]  next;
        input [15:0] last;
        begin
            bus(at,              R, 8'h60,      "RTS");
            bus(at + 16'd1,      R, next,       "  the next byte, not used");
            bus_stack(                          "  the stack, read for nothing");
            s = (s + 1) & 255;
            bus({8'h01, s[7:0]}, R, last[7:0],  "  pc, low byte, pulled");
            s = (s + 1) & 255;
            bus({8'h01, s[7:0]}, R, last[15:8], "  pc, high byte, pulled");
            bus(last,            R, 8'hC0,      "  the last byte of the JSR, again");
        end
    endtask

    // show, called by the JSR whose last byte is at last, with this pattern.
    task plan_show;
        input [15:0] last;
        input [7:0]  pattern;
        integer      lap;
        begin
            bus(16'hC020, R, 8'h8D,   "STA $8000");
            bus(16'hC021, R, 8'h00,   "  the address, low byte");
            bus(16'hC022, R, 8'h80,   "  the address, high byte");
            bus(16'h8000, W, pattern, "  A, on its way to the LEDs");
            bus(16'hC023, R, 8'hA2,   "LDX #4");
            bus(16'hC024, R, 8'h04,   "  the value");
            for (lap = 1; lap <= 4; lap = lap + 1) begin
                bus(16'hC025, R, 8'hCA, "DEX");
                bus(16'hC026, R, 8'hD0, "  the next byte, not used");
                bus(16'hC026, R, 8'hD0, "BNE $C025");
                bus(16'hC027, R, 8'hFD, "  how far: FD, back 3");
                if (lap < 4) begin
                    bus(16'hC028, R, 8'h60, "  the next opcode, for nothing");
                end
            end
            come_back(16'hC028, 8'h00, last);
        end
    endtask

    // The beginning of the program: LDX #$FF and TXS.
    task plan_start;
        begin
            lines    = 0;
            printing = 1;
            bus(16'hC000, R, 8'hA2, "LDX #$FF");
            bus(16'hC001, R, 8'hFF, "  the value");
            bus(16'hC002, R, 8'h9A, "TXS");
            bus(16'hC003, R, 8'hA9, "  the next byte, not used");
            s = 8'hFF;
        end
    endtask

    // One round, from again: all six LEDs off, the calls that go in, one LED
    // more at each, and the calls that come back. If print is 1, some parts
    // of the round are printed: its beginning, the deepest calls, its end.
    task plan_round;
        input     print;
        integer   level;
        reg [7:0] pattern;
        begin
            lines    = 0;
            printing = print;
            bus(16'hC003, R, 8'hA9, "LDA #0");
            bus(16'hC004, R, 8'h00, "  the value");
            call(16'hC005, 16'hC020, "JSR show");
            plan_show(16'hC007, 8'h00);
            call(16'hC008, 16'hC00E, "JSR deeper");
            pattern = 0;
            for (level = 1; level <= 6; level = level + 1) begin
                pattern = {pattern[6:0], 1'b1};
                bus(16'hC00E, R, 8'h38, "SEC");
                bus(16'hC00F, R, 8'h2A, "  the next byte, not used");
                bus(16'hC00F, R, 8'h2A, "ROL A");
                bus(16'hC010, R, 8'h20, "  the next byte, not used");
                if (level == 6) deepest = lines + 5;    // the last push of this JSR
                call(16'hC010, 16'hC020, "JSR show");
                printing = 0;
                plan_show(16'hC012, pattern);
                printing = print & (level >= 5);
                bus(16'hC013, R, 8'hC9, "CMP #%111111");
                bus(16'hC014, R, 8'h3F, "  the value");
                bus(16'hC015, R, 8'hF0, "BEQ $C01F");
                bus(16'hC016, R, 8'h08, "  how far: 08, forward 8");
                if (level == 6) begin
                    // The six are lit: the branch is taken, to back.
                    bus(16'hC017, R, 8'h48, "  the next opcode, for nothing");
                end else begin
                    bus(16'hC017, R, 8'h48, "PHA");
                    bus(16'hC018, R, 8'h20, "  the next byte, not used");
                    bus({8'h01, s[7:0]}, W, pattern, "  A, pushed");
                    s = (s - 1) & 255;
                    if (level == 5) sixth = lines + 3;  // the read for nothing of this JSR
                    call(16'hC018, 16'hC00E, "JSR deeper");
                end
            end
            // The sixth call comes back to the fifth, which comes back to the
            // fourth, and so on: each one takes its pattern back from the stack.
            come_back(16'hC01F, 8'h8D, 16'hC01A);
            for (level = 5; level >= 1; level = level - 1) begin
                pattern  = pattern >> 1;
                printing = print & (level == 5);
                bus(16'hC01B, R, 8'h68, "PLA");
                bus(16'hC01C, R, 8'h20, "  the next byte, not used");
                bus_stack(              "  the stack, read for nothing");
                s = (s + 1) & 255;
                bus({8'h01, s[7:0]}, R, pattern, "  A, pulled");
                call(16'hC01C, 16'hC020, "JSR show");
                printing = 0;
                plan_show(16'hC01E, pattern);
                printing = print & (level == 1);
                come_back(16'hC01F, 8'h8D, (level == 1) ? 16'hC00A : 16'hC01A);
            end
            bus(16'hC00B, R, 8'h4C, "JMP $C003");
            bus(16'hC00C, R, 8'h03, "  the address, low byte");
            bus(16'hC00D, R, 8'hC0, "  the address, high byte");
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
            14:      state_name = "PUSH";
            15:      state_name = "STACK_WAIT";
            16:      state_name = "PULL";
            17:      state_name = "PUSH_HIGH";
            18:      state_name = "PULL_HIGH";
            19:      state_name = "RETURN";
            default: state_name = "?";
        endcase
    end

    integer cycle    = 0;       // cycles since the processor started
    integer place    = 0;       // where this cycle is in the list
    integer rounds   = 0;       // rounds written down since the start
    integer patterns = 0;       // how many patterns the program has stored at $8000
    integer stored   = 0;       // the cycle of the last of them
    integer checked  = 0;       // cycles checked since the beginning
    integer errors   = 0;
    integer run      = 1;       // 1 before the reset, 2 after it
    reg     asked    = 0;       // 1 once the processor has asked for its first byte
    reg [7:0] the_byte;
    reg [7:0] wanted;

    initial plan_start;

    // We look at the bus half-way between two ticks, when nothing moves. A
    // step is coming at the next tick: this is the end of a cycle.
    always @(negedge clk) begin
        if (step & ~reset) begin
            if (asked) begin
                cycle    = cycle + 1;
                place    = place + 1;
                checked  = checked + 1;
                the_byte = write ? data_out : data_in;
                wanted   = from_stack[place] ? stack[expected_address[place][7:0]] : expected_byte[place];
                if (shown[place]) begin
                    $display("cycle %4d: %-12s %h %s %h   %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, comment[place]);
                end
                if (address !== expected_address[place] || write !== expected_write[place]
                                                        || the_byte !== wanted) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: cycle %0d is %h %s %h, expected %h %s %h",
                                               cycle, address, write ? "write" : "read ", the_byte,
                                               expected_address[place],
                                               expected_write[place] ? "write" : "read ", wanted);
                end
                // A byte written in page 1: the copy of the stack keeps it.
                if (write && address[15:8] == 8'h01) begin
                    stack[address[7:0]] = data_out;
                end
                // A pattern is on its way to the LEDs.
                if (write && address == 16'h8000) begin
                    patterns = patterns + 1;
                    if (patterns == 1) begin
                        $display("pattern %2d: %b, at cycle %0d", patterns, data_out[5:0], cycle);
                    end else begin
                        $display("pattern %2d: %b, %0d cycles after the one before", patterns,
                                 data_out[5:0], cycle - stored);
                    end
                    stored = cycle;
                end
                // The stack at its deepest, in the first round: what page 1 holds.
                if (place == deepest && run == 1 && rounds == 1) begin
                    $display("the stack at its deepest, S = %h: from $01FF down, it holds", dut.processor.s);
                    for (n = 255; n > dut.processor.s; n = n - 1) begin
                        $display("  $01%h  %h", n[7:0], dut.the_ram.cells[16'h0100 + n]);
                    end
                end
                // The end of the list: write down the next round.
                if (place == lines) begin
                    rounds = rounds + 1;
                    plan_round(rounds == 1 && run == 1);
                    // After the reset, print the first call: S is $FF again.
                    if (rounds == 1 && run == 2) begin
                        for (n = 1; n <= 8; n = n + 1) shown[n] = 1;
                    end
                    place  = 0;
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
    // patterns it is waiting for never come, it gives up after 20,000 ticks.
    initial begin
        #200000;
        $display("FAIL: computer, still waiting after 20,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Keep the waveform small: up to the second pattern.
        wait (patterns == 2);
        $dumpoff;

        // A reset starts the program again. It comes at the worst moment: in
        // the second round, the fifth call is calling the sixth, and the
        // processor has just begun to push the high byte of pc. That byte
        // still reaches the RAM, at the next tick.
        wait (rounds == 2 && place == sixth);
        @(posedge clk);
        #1;
        $display("reset, while %h is being written at %h", data_out, address);
        if (write && address[15:8] == 8'h01) stack[address[7:0]] = data_out;
        reset    = 1;
        asked    = 0;
        cycle    = 0;
        place    = 0;
        patterns = 0;
        rounds   = 0;
        run      = 2;
        plan_start;
        repeat (3) @(posedge clk);
        #1 reset = 0;

        // Then two whole rounds, from the start. S is $FF again: TXS put it
        // there, not the reset.
        wait (rounds == 3);
        @(negedge clk);
        if (patterns != 24) begin
            errors = errors + 1;
            $display("wrong: %0d patterns stored at $8000 in two rounds, expected 24", patterns);
        end

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, calls six deep and back, and the LEDs",
                     checked);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
