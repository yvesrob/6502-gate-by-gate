// Chapter 15 uses the branches_tb from chapter 13, with two changes, each
// marked "Chapter 15": the wires IRQ and NMI, held at 0, and the seven
// cycles of the reset, which go by before the comparison begins.
// Chapter 13, test bench for the new instructions, with a program of its own,
// branches.s. Every cycle of the bus is compared with a list written from the
// tables of cycles of 64doc, as in arithmetic_tb, and the list says what each
// instruction leaves in A and in the five flags, and now in X and Y as well,
// for the transfers. A branch taken and a branch not taken differ on the bus
// by one cycle, and by two when the branch goes to another page.
`timescale 1ns/1ns
module branches_tb;
    reg         clk = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;

    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    // The same computer, with another file in its ROM.
    computer #(.PROGRAM("branches.hex")) dut (
        .clk      (clk),
        .reset    (1'b0),
        .step     (step),
        .irq      (1'b0),       // Chapter 15: nothing asks for an interrupt here
        .nmi      (1'b0),
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
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.the_ram.cells[n] = 8'h00;
        end
    end

    // The list. opcode_cycle() is the first cycle of an instruction, and
    // next_cycle() each of the others. leaves() says what the instruction
    // leaves behind it: A, X, Y, and the flags N V D Z C, in that order.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:200];
    reg          expected_write   [1:200];
    reg [7:0]    expected_byte    [1:200];
    reg [8*52:1] words            [1:200];
    reg          first            [1:200];
    reg [7:0]    expected_a       [1:80];
    reg [7:0]    expected_x       [1:80];
    reg [7:0]    expected_y       [1:80];
    reg [4:0]    expected_flags   [1:80];
    reg          known            [1:80];   // 1: leaves() was given for this instruction
    integer      lines        = 0;
    integer      instructions = 0;
    integer      lap;

    task opcode_cycle;
        input [15:0]   the_address;
        input [7:0]    the_byte;
        input [8*52:1] the_instruction;
        begin
            lines                   = lines + 1;
            instructions            = instructions + 1;
            expected_address[lines] = the_address;
            expected_write[lines]   = R;
            expected_byte[lines]    = the_byte;
            words[lines]            = the_instruction;
            first[lines]            = 1;
            known[instructions]     = 0;
        end
    endtask

    task next_cycle;
        input [15:0]   the_address;
        input          the_write;
        input [7:0]    the_byte;
        input [8*52:1] the_words;
        begin
            lines                   = lines + 1;
            expected_address[lines] = the_address;
            expected_write[lines]   = the_write;
            expected_byte[lines]    = the_byte;
            words[lines]            = the_words;
            first[lines]            = 0;
        end
    endtask

    task leaves;
        input [7:0] the_a;
        input [7:0] the_x;
        input [7:0] the_y;
        input [4:0] the_flags;      // N V D Z C
        begin
            expected_a[instructions]     = the_a;
            expected_x[instructions]     = the_x;
            expected_y[instructions]     = the_y;
            expected_flags[instructions] = the_flags;
            known[instructions]          = 1;
        end
    endtask

    initial begin
        // Copy a register into another: implied addressing.
        opcode_cycle(16'hC000,    8'hA2, "LDX #$80");
        next_cycle  (16'hC001, R, 8'h80, "fetch value, increment PC");
        leaves(8'h00, 8'h80, 8'h00, 5'b10000);
        opcode_cycle(16'hC002,    8'h8A, "TXA");
        next_cycle  (16'hC003, R, 8'hA8, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h80, 8'h00, 5'b10000);
        opcode_cycle(16'hC003,    8'hA8, "TAY");
        next_cycle  (16'hC004, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h80, 8'h80, 5'b10000);
        opcode_cycle(16'hC004,    8'hA9, "LDA #0");
        next_cycle  (16'hC005, R, 8'h00, "fetch value, increment PC");
        leaves(8'h00, 8'h80, 8'h80, 5'b00010);
        opcode_cycle(16'hC006,    8'hAA, "TAX");
        next_cycle  (16'hC007, R, 8'h98, "read next instruction byte (throw it away)");
        leaves(8'h00, 8'h00, 8'h80, 5'b00010);
        opcode_cycle(16'hC007,    8'h98, "TYA");
        next_cycle  (16'hC008, R, 8'hEA, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC008,    8'hEA, "NOP");
        next_cycle  (16'hC009, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h00, 8'h80, 5'b10000);

        // BIT, in page zero and with a full address.
        opcode_cycle(16'hC009,    8'hA9, "LDA #%11000000");
        next_cycle  (16'hC00A, R, 8'hC0, "fetch value, increment PC");
        leaves(8'hC0, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC00B,    8'h85, "STA $30");
        next_cycle  (16'hC00C, R, 8'h30, "fetch address, increment PC");
        next_cycle  (16'h0030, W, 8'hC0, "write register to effective address");
        leaves(8'hC0, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC00D,    8'hA9, "LDA #%00000001");
        next_cycle  (16'hC00E, R, 8'h01, "fetch value, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC00F,    8'h24, "BIT $30");
        next_cycle  (16'hC010, R, 8'h30, "fetch address, increment PC");
        next_cycle  (16'h0030, R, 8'hC0, "read from effective address");
        leaves(8'h01, 8'h00, 8'h80, 5'b11010);    // C0: N and V; 01 AND C0 is 0: Z
        opcode_cycle(16'hC011,    8'h2C, "BIT bits");
        next_cycle  (16'hC012, R, 8'h0A, "fetch low byte of address, increment PC");
        next_cycle  (16'hC013, R, 8'hC1, "fetch high byte of address, increment PC");
        next_cycle  (16'hC10A, R, 8'h41, "read from effective address");
        leaves(8'h01, 8'h00, 8'h80, 5'b01000);    // 41: V only; 01 AND 41 is 01

        // V. Relative addressing: a branch not taken is two cycles, a
        // branch taken three.
        opcode_cycle(16'hC014,    8'h50, "BVC over1");
        next_cycle  (16'hC015, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b01000);
        opcode_cycle(16'hC016,    8'h70, "BVS over1");
        next_cycle  (16'hC017, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC018, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h01, 8'h00, 8'h80, 5'b01000);
        opcode_cycle(16'hC01A,    8'hB8, "CLV");
        next_cycle  (16'hC01B, R, 8'h70, "read next instruction byte (throw it away)");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC01B,    8'h70, "BVS over2");
        next_cycle  (16'hC01C, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC01D,    8'h50, "BVC over2");
        next_cycle  (16'hC01E, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC01F, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);

        // Z, after a comparison.
        opcode_cycle(16'hC021,    8'hA9, "LDA #$42");
        next_cycle  (16'hC022, R, 8'h42, "fetch value, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC023,    8'hC9, "CMP #$42");
        next_cycle  (16'hC024, R, 8'h42, "fetch value, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00011);
        opcode_cycle(16'hC025,    8'hD0, "BNE over3");
        next_cycle  (16'hC026, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00011);
        opcode_cycle(16'hC027,    8'hF0, "BEQ over3");
        next_cycle  (16'hC028, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC029, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h42, 8'h00, 8'h80, 5'b00011);
        opcode_cycle(16'hC02B,    8'hC9, "CMP #$41");
        next_cycle  (16'hC02C, R, 8'h41, "fetch value, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00001);
        opcode_cycle(16'hC02D,    8'hF0, "BEQ over4");
        next_cycle  (16'hC02E, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00001);
        opcode_cycle(16'hC02F,    8'hD0, "BNE over4");
        next_cycle  (16'hC030, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC031, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h42, 8'h00, 8'h80, 5'b00001);

        // C.
        opcode_cycle(16'hC033,    8'h90, "BCC over5");
        next_cycle  (16'hC034, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b00001);
        opcode_cycle(16'hC035,    8'hB0, "BCS over5");
        next_cycle  (16'hC036, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC037, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h42, 8'h00, 8'h80, 5'b00001);
        opcode_cycle(16'hC039,    8'hC9, "CMP #$43");
        next_cycle  (16'hC03A, R, 8'h43, "fetch value, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC03B,    8'hB0, "BCS over6");
        next_cycle  (16'hC03C, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC03D,    8'h90, "BCC over6");
        next_cycle  (16'hC03E, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC03F, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h42, 8'h00, 8'h80, 5'b10000);

        // N.
        opcode_cycle(16'hC041,    8'h10, "BPL over7");
        next_cycle  (16'hC042, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h42, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC043,    8'h30, "BMI over7");
        next_cycle  (16'hC044, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC045, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h42, 8'h00, 8'h80, 5'b10000);
        opcode_cycle(16'hC047,    8'hA9, "LDA #$01");
        next_cycle  (16'hC048, R, 8'h01, "fetch value, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC049,    8'h30, "BMI over8");
        next_cycle  (16'hC04A, R, 8'h04, "fetch operand, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);
        opcode_cycle(16'hC04B,    8'h10, "BPL over8");
        next_cycle  (16'hC04C, R, 8'h02, "fetch operand, increment PC");
        next_cycle  (16'hC04D, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
        leaves(8'h01, 8'h00, 8'h80, 5'b00000);

        // The loop over two pages.
        opcode_cycle(16'hC04F,    8'hA2, "LDX #0");
        next_cycle  (16'hC050, R, 8'h00, "fetch value, increment PC");
        leaves(8'h01, 8'h00, 8'h80, 5'b00010);
        opcode_cycle(16'hC051,    8'hA0, "LDY #3");
        next_cycle  (16'hC052, R, 8'h03, "fetch value, increment PC");
        leaves(8'h01, 8'h00, 8'h03, 5'b00000);
        opcode_cycle(16'hC053,    8'h4C, "JMP lap");
        next_cycle  (16'hC054, R, 8'hFC, "fetch low address byte, increment PC");
        next_cycle  (16'hC055, R, 8'hC0, "copy low address byte to PCL, fetch high");
        leaves(8'h01, 8'h00, 8'h03, 5'b00000);
        for (lap = 1; lap <= 3; lap = lap + 1) begin
            opcode_cycle(16'hC0FC,    8'hE8, "INX");
            next_cycle  (16'hC0FD, R, 8'h50, "read next instruction byte (throw it away)");
            leaves(8'h01, lap, 4 - lap, 5'b00000);
            // Forward, into page $C1: $C0FF + 2 is $C101. The low byte comes
            // first: $C001, on the old page, is read for nothing.
            opcode_cycle(16'hC0FD,    8'h50, "BVC ahead");
            next_cycle  (16'hC0FE, R, 8'h02, "fetch operand, increment PC");
            next_cycle  (16'hC0FF, R, 8'hA9, "fetch opcode of next instruction, add operand to PCL");
            next_cycle  (16'hC001, R, 8'h80, "fetch opcode, fix PCH");
            leaves(8'h01, lap, 4 - lap, 5'b00000);
            opcode_cycle(16'hC101,    8'h88, "DEY");
            next_cycle  (16'hC102, R, 8'hD0, "read next instruction byte (throw it away)");
            leaves(8'h01, lap, 3 - lap, (lap == 3) ? 5'b00010 : 5'b00000);
            opcode_cycle(16'hC102,    8'hD0, "BNE lap");
            next_cycle  (16'hC103, R, 8'hF8, "fetch operand, increment PC");
            if (lap < 3) begin
                // Backward, into page $C0: $C104 - 8 is $C0FC. The low byte
                // comes first: $C1FC, on the old page, is read for nothing.
                next_cycle  (16'hC104, R, 8'h8E, "fetch opcode of next instruction, add operand to PCL");
                next_cycle  (16'hC1FC, R, 8'h00, "fetch opcode, fix PCH");
            end
            leaves(8'h01, lap, 3 - lap, (lap == 3) ? 5'b00010 : 5'b00000);
        end
        opcode_cycle(16'hC104,    8'h8E, "STX LEDS");
        next_cycle  (16'hC105, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC106, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8000, W, 8'h03, "write register to effective address");
        leaves(8'h01, 8'h03, 8'h00, 5'b00010);

        // Absolute addressing (JMP): the end, twice.
        opcode_cycle(16'hC107,    8'h4C, "JMP done");
        next_cycle  (16'hC108, R, 8'h07, "fetch low address byte, increment PC");
        next_cycle  (16'hC109, R, 8'hC1, "copy low address byte to PCL, fetch high");
        leaves(8'h01, 8'h03, 8'h00, 5'b00010);
        opcode_cycle(16'hC107,    8'h4C, "JMP done");
        next_cycle  (16'hC108, R, 8'h07, "fetch low address byte, increment PC");
        next_cycle  (16'hC109, R, 8'hC1, "copy low address byte to PCL, fetch high");
    end

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

    // The five flags of the processor, in the order the 6502 prints them.
    wire [4:0] flags;
    assign flags = {dut.processor.negative, dut.processor.overflow, dut.processor.decimal,
                    dut.processor.zero, dut.processor.carry};

    integer cycle   = 0;
    integer done    = 0;        // instructions finished so far
    integer errors  = 0;
    integer asked   = 0;      // Chapter 15: the seven cycles of the reset go by first
    reg [7:0] the_byte;

    // At the end of every cycle, compare the bus with the next line of the
    // list. When a new instruction begins, the one before it has finished:
    // compare A, X, Y and the flags with what it should have left.
    always @(negedge clk) begin
        if (step) begin
            if (asked == 7 && cycle < lines) begin
                cycle    = cycle + 1;
                the_byte = write ? data_out : data_in;
                if (first[cycle] && done > 0 && known[done]) begin
                    $display("                         A = %h  X = %h  Y = %h   N V D Z C = %b %b %b %b %b",
                             dut.processor.a, dut.processor.x, dut.processor.y,
                             flags[4], flags[3], flags[2], flags[1], flags[0]);
                    if (dut.processor.a !== expected_a[done] || dut.processor.x !== expected_x[done]
                     || dut.processor.y !== expected_y[done] || flags !== expected_flags[done]) begin
                        errors = errors + 1;
                        $display("                         ^ wrong, expected A = %h  X = %h  Y = %h   N V D Z C = %b %b %b %b %b",
                                 expected_a[done], expected_x[done], expected_y[done],
                                 expected_flags[done][4], expected_flags[done][3], expected_flags[done][2],
                                 expected_flags[done][1], expected_flags[done][0]);
                    end
                end
                if (first[cycle]) begin
                    done = done + 1;
                    $display("cycle %3d: %-12s %h %s %h   %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, words[cycle]);
                end else begin
                    $display("cycle %3d: %-12s %h %s %h     %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, words[cycle]);
                end
                if (address !== expected_address[cycle] || write !== expected_write[cycle]
                                                        || the_byte !== expected_byte[cycle]) begin
                    errors = errors + 1;
                    $display("           ^ wrong, expected %h %s %h", expected_address[cycle],
                             expected_write[cycle] ? "write" : "read ", expected_byte[cycle]);
                end
            end
            if (asked < 7) asked = asked + 1;
        end
    end

    // The LEDs must show the last byte written at $8000, and nothing else.
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

    // A test bench that waits for a processor needs a time limit.
    initial begin
        #10000;
        $display("FAIL: branches, still waiting after 1,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("branches_tb.vcd");
        $dumpvars(0, branches_tb);

        wait (lines > 0 && cycle == lines);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: branches, %0d cycles of %0d instructions as the tables of 64doc say, and A, X, Y and the flags after each",
                     lines, instructions);
            $finish;
        end else begin
            $display("FAIL: branches, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
