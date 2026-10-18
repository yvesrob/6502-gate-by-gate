// Chapter 17 uses the arithmetic_tb from chapter 15. This file is a copy of it, unchanged.
// Chapter 15 uses the arithmetic_tb from chapter 12, with two changes, each
// marked "Chapter 15": the wires IRQ and NMI, held at 0, and the seven
// cycles of the reset, which go by before the comparison begins.
// Chapter 12, test bench for the new instructions, with a program of its own,
// arithmetic.s. Every cycle of the bus is compared with a list written from
// the tables of cycles of 64doc, as in modes_tb. And since a comparison
// changes nothing but the flags, the list also says what each instruction
// leaves in A and in the five flags, and the test bench looks inside the
// processor to check them.
`timescale 1ns/1ns
module arithmetic_tb;
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
    computer #(.PROGRAM("arithmetic.hex")) dut (
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
    // leaves behind it: A, and the flags N V D Z C, in that order.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:200];
    reg          expected_write   [1:200];
    reg [7:0]    expected_byte    [1:200];
    reg [8*46:1] words            [1:200];
    reg          first            [1:200];
    reg [7:0]    expected_a       [1:80];
    reg [4:0]    expected_flags   [1:80];
    reg          known            [1:80];   // 1: leaves() was given for this instruction
    integer      lines        = 0;
    integer      instructions = 0;

    task opcode_cycle;
        input [15:0]   the_address;
        input [7:0]    the_byte;
        input [8*46:1] the_instruction;
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
        input [8*46:1] the_words;
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
        input [4:0] the_flags;      // N V D Z C
        begin
            expected_a[instructions]     = the_a;
            expected_flags[instructions] = the_flags;
            known[instructions]          = 1;
        end
    endtask

    initial begin
        // Two numbers of two bytes in the zero page.
        opcode_cycle(16'hC000,    8'hA9, "LDA #$90");
        next_cycle  (16'hC001, R, 8'h90, "fetch value, increment PC");
        leaves(8'h90, 5'b10000);
        opcode_cycle(16'hC002,    8'h85, "STA $20");
        next_cycle  (16'hC003, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, W, 8'h90, "write register to effective address");
        leaves(8'h90, 5'b10000);
        opcode_cycle(16'hC004,    8'hA9, "LDA #$12");
        next_cycle  (16'hC005, R, 8'h12, "fetch value, increment PC");
        leaves(8'h12, 5'b00000);
        opcode_cycle(16'hC006,    8'h85, "STA $21");
        next_cycle  (16'hC007, R, 8'h21, "fetch address, increment PC");
        next_cycle  (16'h0021, W, 8'h12, "write register to effective address");
        leaves(8'h12, 5'b00000);
        opcode_cycle(16'hC008,    8'hA9, "LDA #$A0");
        next_cycle  (16'hC009, R, 8'hA0, "fetch value, increment PC");
        leaves(8'hA0, 5'b10000);
        opcode_cycle(16'hC00A,    8'h85, "STA $22");
        next_cycle  (16'hC00B, R, 8'h22, "fetch address, increment PC");
        next_cycle  (16'h0022, W, 8'hA0, "write register to effective address");
        leaves(8'hA0, 5'b10000);
        opcode_cycle(16'hC00C,    8'hA9, "LDA #$01");
        next_cycle  (16'hC00D, R, 8'h01, "fetch value, increment PC");
        leaves(8'h01, 5'b00000);
        opcode_cycle(16'hC00E,    8'h85, "STA $23");
        next_cycle  (16'hC00F, R, 8'h23, "fetch address, increment PC");
        next_cycle  (16'h0023, W, 8'h01, "write register to effective address");
        leaves(8'h01, 5'b00000);

        // Their sum: $1290 + $01A0 = $1430.
        opcode_cycle(16'hC010,    8'h18, "CLC");
        next_cycle  (16'hC011, R, 8'hA5, "read next instruction byte (throw it away)");
        leaves(8'h01, 5'b00000);
        opcode_cycle(16'hC011,    8'hA5, "LDA $20");
        next_cycle  (16'hC012, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, R, 8'h90, "read from effective address");
        leaves(8'h90, 5'b10000);
        opcode_cycle(16'hC013,    8'h65, "ADC $22");
        next_cycle  (16'hC014, R, 8'h22, "fetch address, increment PC");
        next_cycle  (16'h0022, R, 8'hA0, "read from effective address");
        leaves(8'h30, 5'b01001);    // 90 + A0 = 130: a carry, and two negatives gave a positive: V
        opcode_cycle(16'hC015,    8'h85, "STA $24");
        next_cycle  (16'hC016, R, 8'h24, "fetch address, increment PC");
        next_cycle  (16'h0024, W, 8'h30, "write register to effective address");
        leaves(8'h30, 5'b01001);
        opcode_cycle(16'hC017,    8'hA5, "LDA $21");
        next_cycle  (16'hC018, R, 8'h21, "fetch address, increment PC");
        next_cycle  (16'h0021, R, 8'h12, "read from effective address");
        leaves(8'h12, 5'b01001);
        opcode_cycle(16'hC019,    8'h65, "ADC $23");
        next_cycle  (16'hC01A, R, 8'h23, "fetch address, increment PC");
        next_cycle  (16'h0023, R, 8'h01, "read from effective address");
        leaves(8'h14, 5'b00000);    // 12 + 01 + the carry
        opcode_cycle(16'hC01B,    8'h85, "STA $25");
        next_cycle  (16'hC01C, R, 8'h25, "fetch address, increment PC");
        next_cycle  (16'h0025, W, 8'h14, "write register to effective address");
        leaves(8'h14, 5'b00000);

        // Their difference: $1290 - $01A0 = $10F0.
        opcode_cycle(16'hC01D,    8'h38, "SEC");
        next_cycle  (16'hC01E, R, 8'hA5, "read next instruction byte (throw it away)");
        leaves(8'h14, 5'b00001);
        opcode_cycle(16'hC01E,    8'hA5, "LDA $20");
        next_cycle  (16'hC01F, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, R, 8'h90, "read from effective address");
        leaves(8'h90, 5'b10001);
        opcode_cycle(16'hC020,    8'hE5, "SBC $22");
        next_cycle  (16'hC021, R, 8'h22, "fetch address, increment PC");
        next_cycle  (16'h0022, R, 8'hA0, "read from effective address");
        leaves(8'hF0, 5'b10000);    // 90 - A0 = -10: F0, and a borrow (C = 0)
        opcode_cycle(16'hC022,    8'h85, "STA $26");
        next_cycle  (16'hC023, R, 8'h26, "fetch address, increment PC");
        next_cycle  (16'h0026, W, 8'hF0, "write register to effective address");
        leaves(8'hF0, 5'b10000);
        opcode_cycle(16'hC024,    8'hA5, "LDA $21");
        next_cycle  (16'hC025, R, 8'h21, "fetch address, increment PC");
        next_cycle  (16'h0021, R, 8'h12, "read from effective address");
        leaves(8'h12, 5'b00000);
        opcode_cycle(16'hC026,    8'hE5, "SBC $23");
        next_cycle  (16'hC027, R, 8'h23, "fetch address, increment PC");
        next_cycle  (16'h0023, R, 8'h01, "read from effective address");
        leaves(8'h10, 5'b00001);    // 12 - 01 - the borrow, and no borrow now
        opcode_cycle(16'hC028,    8'h85, "STA $27");
        next_cycle  (16'hC029, R, 8'h27, "fetch address, increment PC");
        next_cycle  (16'h0027, W, 8'h10, "write register to effective address");
        leaves(8'h10, 5'b00001);

        // In decimal: 1995 + 0027 = 2022.
        opcode_cycle(16'hC02A,    8'hF8, "SED");
        next_cycle  (16'hC02B, R, 8'h18, "read next instruction byte (throw it away)");
        leaves(8'h10, 5'b00101);
        opcode_cycle(16'hC02B,    8'h18, "CLC");
        next_cycle  (16'hC02C, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h10, 5'b00100);
        opcode_cycle(16'hC02C,    8'hA9, "LDA #$95");
        next_cycle  (16'hC02D, R, 8'h95, "fetch value, increment PC");
        leaves(8'h95, 5'b10100);
        opcode_cycle(16'hC02E,    8'h69, "ADC #$27");
        next_cycle  (16'hC02F, R, 8'h27, "fetch value, increment PC");
        leaves(8'h22, 5'b10101);    // 95 + 27 = 122: 22, and a carry. N is 1: see alu.v
        opcode_cycle(16'hC030,    8'h85, "STA $28");
        next_cycle  (16'hC031, R, 8'h28, "fetch address, increment PC");
        next_cycle  (16'h0028, W, 8'h22, "write register to effective address");
        leaves(8'h22, 5'b10101);
        opcode_cycle(16'hC032,    8'hA9, "LDA #$19");
        next_cycle  (16'hC033, R, 8'h19, "fetch value, increment PC");
        leaves(8'h19, 5'b00101);
        opcode_cycle(16'hC034,    8'h69, "ADC #$00");
        next_cycle  (16'hC035, R, 8'h00, "fetch value, increment PC");
        leaves(8'h20, 5'b00100);    // 19 + 00 + the carry = 20
        opcode_cycle(16'hC036,    8'h85, "STA $29");
        next_cycle  (16'hC037, R, 8'h29, "fetch address, increment PC");
        next_cycle  (16'h0029, W, 8'h20, "write register to effective address");
        leaves(8'h20, 5'b00100);

        // And back again: 2022 - 0027 = 1995.
        opcode_cycle(16'hC038,    8'h38, "SEC");
        next_cycle  (16'hC039, R, 8'hA5, "read next instruction byte (throw it away)");
        leaves(8'h20, 5'b00101);
        opcode_cycle(16'hC039,    8'hA5, "LDA $28");
        next_cycle  (16'hC03A, R, 8'h28, "fetch address, increment PC");
        next_cycle  (16'h0028, R, 8'h22, "read from effective address");
        leaves(8'h22, 5'b00101);
        opcode_cycle(16'hC03B,    8'hE9, "SBC #$27");
        next_cycle  (16'hC03C, R, 8'h27, "fetch value, increment PC");
        leaves(8'h95, 5'b10100);    // 22 - 27: 95, and a borrow. The flags are those of binary
        opcode_cycle(16'hC03D,    8'h85, "STA $2A");
        next_cycle  (16'hC03E, R, 8'h2A, "fetch address, increment PC");
        next_cycle  (16'h002A, W, 8'h95, "write register to effective address");
        leaves(8'h95, 5'b10100);
        opcode_cycle(16'hC03F,    8'hA5, "LDA $29");
        next_cycle  (16'hC040, R, 8'h29, "fetch address, increment PC");
        next_cycle  (16'h0029, R, 8'h20, "read from effective address");
        leaves(8'h20, 5'b00100);
        opcode_cycle(16'hC041,    8'hE9, "SBC #$00");
        next_cycle  (16'hC042, R, 8'h00, "fetch value, increment PC");
        leaves(8'h19, 5'b00101);    // 20 - 00 - the borrow = 19
        opcode_cycle(16'hC043,    8'h85, "STA $2B");
        next_cycle  (16'hC044, R, 8'h2B, "fetch address, increment PC");
        next_cycle  (16'h002B, W, 8'h19, "write register to effective address");
        leaves(8'h19, 5'b00101);
        opcode_cycle(16'hC045,    8'hD8, "CLD");
        next_cycle  (16'hC046, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h19, 5'b00001);

        // Compare.
        opcode_cycle(16'hC046,    8'hA9, "LDA #$42");
        next_cycle  (16'hC047, R, 8'h42, "fetch value, increment PC");
        leaves(8'h42, 5'b00001);
        opcode_cycle(16'hC048,    8'hC9, "CMP #$41");
        next_cycle  (16'hC049, R, 8'h41, "fetch value, increment PC");
        leaves(8'h42, 5'b00001);    // larger: C = 1
        opcode_cycle(16'hC04A,    8'hC9, "CMP #$42");
        next_cycle  (16'hC04B, R, 8'h42, "fetch value, increment PC");
        leaves(8'h42, 5'b00011);    // the same: Z = 1, C = 1
        opcode_cycle(16'hC04C,    8'hC9, "CMP #$43");
        next_cycle  (16'hC04D, R, 8'h43, "fetch value, increment PC");
        leaves(8'h42, 5'b10000);    // smaller: C = 0, and 42 - 43 is FF: N = 1
        opcode_cycle(16'hC04E,    8'hA6, "LDX $25");
        next_cycle  (16'hC04F, R, 8'h25, "fetch address, increment PC");
        next_cycle  (16'h0025, R, 8'h14, "read from effective address");
        leaves(8'h42, 5'b00000);
        opcode_cycle(16'hC050,    8'hE0, "CPX #$14");
        next_cycle  (16'hC051, R, 8'h14, "fetch value, increment PC");
        leaves(8'h42, 5'b00011);    // the same
        opcode_cycle(16'hC052,    8'hA4, "LDY $27");
        next_cycle  (16'hC053, R, 8'h27, "fetch address, increment PC");
        next_cycle  (16'h0027, R, 8'h10, "read from effective address");
        leaves(8'h42, 5'b00001);
        opcode_cycle(16'hC054,    8'hC4, "CPY $25");
        next_cycle  (16'hC055, R, 8'h25, "fetch address, increment PC");
        next_cycle  (16'h0025, R, 8'h14, "read from effective address");
        leaves(8'h42, 5'b10000);    // 10 - 14 is FC: smaller

        // Bit by bit.
        opcode_cycle(16'hC056,    8'hA9, "LDA #%11001100");
        next_cycle  (16'hC057, R, 8'hCC, "fetch value, increment PC");
        leaves(8'hCC, 5'b10000);
        opcode_cycle(16'hC058,    8'h29, "AND #%10101010");
        next_cycle  (16'hC059, R, 8'hAA, "fetch value, increment PC");
        leaves(8'h88, 5'b10000);
        opcode_cycle(16'hC05A,    8'h09, "ORA #%00000011");
        next_cycle  (16'hC05B, R, 8'h03, "fetch value, increment PC");
        leaves(8'h8B, 5'b10000);
        opcode_cycle(16'hC05C,    8'h49, "EOR #%11111111");
        next_cycle  (16'hC05D, R, 8'hFF, "fetch value, increment PC");
        leaves(8'h74, 5'b00000);

        // Shifts on A: accumulator addressing.
        opcode_cycle(16'hC05E,    8'hA9, "LDA #%10010110");
        next_cycle  (16'hC05F, R, 8'h96, "fetch value, increment PC");
        leaves(8'h96, 5'b10000);
        opcode_cycle(16'hC060,    8'h0A, "ASL A");
        next_cycle  (16'hC061, R, 8'h2A, "read next instruction byte (throw it away)");
        leaves(8'h2C, 5'b00001);
        opcode_cycle(16'hC061,    8'h2A, "ROL A");
        next_cycle  (16'hC062, R, 8'h4A, "read next instruction byte (throw it away)");
        leaves(8'h59, 5'b00000);
        opcode_cycle(16'hC062,    8'h4A, "LSR A");
        next_cycle  (16'hC063, R, 8'h6A, "read next instruction byte (throw it away)");
        leaves(8'h2C, 5'b00001);
        opcode_cycle(16'hC063,    8'h6A, "ROR A");
        next_cycle  (16'hC064, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h96, 5'b10000);

        // Shifts on a byte of memory: Read-Modify-Write instructions.
        opcode_cycle(16'hC064,    8'hA9, "LDA #%01000001");
        next_cycle  (16'hC065, R, 8'h41, "fetch value, increment PC");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC066,    8'h8D, "STA $0300");
        next_cycle  (16'hC067, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC068, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, W, 8'h41, "write register to effective address");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC069,    8'h0E, "ASL $0300");
        next_cycle  (16'hC06A, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC06B, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, R, 8'h41, "read from effective address");
        next_cycle  (16'h0300, W, 8'h41, "write the value back, do the operation on it");
        next_cycle  (16'h0300, W, 8'h82, "write the new value to effective address");
        leaves(8'h41, 5'b10000);
        opcode_cycle(16'hC06C,    8'hA2, "LDX #$10");
        next_cycle  (16'hC06D, R, 8'h10, "fetch value, increment PC");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC06E,    8'h5E, "LSR $02F0,X");
        next_cycle  (16'hC06F, R, 8'hF0, "fetch low byte of address, increment PC");
        next_cycle  (16'hC070, R, 8'h02, "fetch high byte, add index X to low byte");
        next_cycle  (16'h0200, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h0300, R, 8'h82, "re-read from effective address");
        next_cycle  (16'h0300, W, 8'h82, "write the value back, do the operation on it");
        next_cycle  (16'h0300, W, 8'h41, "write the new value to effective address");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC071,    8'hAD, "LDA $0300");
        next_cycle  (16'hC072, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC073, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, R, 8'h41, "read from effective address");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC074,    8'h8D, "STA LEDS");
        next_cycle  (16'hC075, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC076, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8000, W, 8'h41, "write register to effective address");
        leaves(8'h41, 5'b00000);

        // Absolute addressing (JMP): the end, twice.
        opcode_cycle(16'hC077,    8'h4C, "JMP done");
        next_cycle  (16'hC078, R, 8'h77, "fetch low address byte, increment PC");
        next_cycle  (16'hC079, R, 8'hC0, "copy low address byte to PCL, fetch high");
        leaves(8'h41, 5'b00000);
        opcode_cycle(16'hC077,    8'h4C, "JMP done");
        next_cycle  (16'hC078, R, 8'h77, "fetch low address byte, increment PC");
        next_cycle  (16'hC079, R, 8'hC0, "copy low address byte to PCL, fetch high");
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
    // compare A and the flags with what it should have left.
    always @(negedge clk) begin
        if (step) begin
            if (asked == 7 && cycle < lines) begin
                cycle    = cycle + 1;
                the_byte = write ? data_out : data_in;
                if (first[cycle] && done > 0 && known[done]) begin
                    $display("                         A = %h   N V D Z C = %b %b %b %b %b",
                             dut.processor.a, flags[4], flags[3], flags[2], flags[1], flags[0]);
                    if (dut.processor.a !== expected_a[done] || flags !== expected_flags[done]) begin
                        errors = errors + 1;
                        $display("                         ^ wrong, expected A = %h   N V D Z C = %b %b %b %b %b",
                                 expected_a[done], expected_flags[done][4], expected_flags[done][3],
                                 expected_flags[done][2], expected_flags[done][1], expected_flags[done][0]);
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
        $display("FAIL: arithmetic, still waiting after 1,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("arithmetic_tb.vcd");
        $dumpvars(0, arithmetic_tb);

        wait (lines > 0 && cycle == lines);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: arithmetic, %0d cycles of %0d instructions as the tables of 64doc say, and A and the flags after each",
                     lines, instructions);
            $finish;
        end else begin
            $display("FAIL: arithmetic, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
