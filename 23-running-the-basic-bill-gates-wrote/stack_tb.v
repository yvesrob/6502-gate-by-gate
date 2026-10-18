// Chapter 23 uses the stack_tb from chapter 15. This file is a copy of it, unchanged.
// Chapter 15 uses the stack_tb from chapter 14, with three changes, each
// marked "Chapter 15": the wires IRQ and NMI, held at 0, the seven cycles of
// the reset, which go by before the comparison begins, and S, which the reset
// takes from 00 to FD before TXS sets it.
// Chapter 14, test bench for the new instructions, with a program of its own,
// stack.s. Every cycle of the bus is compared with a list written from the
// tables of cycles of 64doc, as in branches_tb, and the list says what each
// instruction leaves in A, X, Y and the five flags, and now in S as well.
// The bytes that the stack instructions write and read are on the bus: the
// list says where each one goes, and the test bench sees that the stack
// stays in page 1 when S goes round from $00 to $FF, and back.
`timescale 1ns/1ns
module stack_tb;
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
    computer #(.PROGRAM("stack.hex")) dut (
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
    // leaves behind it: A, X, Y, S, and the flags N V D Z C, in that order.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:250];
    reg          expected_write   [1:250];
    reg [7:0]    expected_byte    [1:250];
    reg [8*62:1] words            [1:250];
    reg          first            [1:250];
    reg [7:0]    expected_a       [1:80];
    reg [7:0]    expected_x       [1:80];
    reg [7:0]    expected_y       [1:80];
    reg [7:0]    expected_s       [1:80];
    reg [4:0]    expected_flags   [1:80];
    reg          known            [1:80];   // 1: leaves() was given for this instruction
    integer      lines        = 0;
    integer      instructions = 0;

    task opcode_cycle;
        input [15:0]   the_address;
        input [7:0]    the_byte;
        input [8*62:1] the_instruction;
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
        input [8*62:1] the_words;
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
        input [7:0] the_s;
        input [4:0] the_flags;      // N V D Z C
        begin
            expected_a[instructions]     = the_a;
            expected_x[instructions]     = the_x;
            expected_y[instructions]     = the_y;
            expected_s[instructions]     = the_s;
            expected_flags[instructions] = the_flags;
            known[instructions]          = 1;
        end
    endtask

    initial begin
        // S and X: implied addressing, two cycles each.
        opcode_cycle(16'hC000,    8'hA2, "LDX #0");
        next_cycle  (16'hC001, R, 8'h00, "fetch value, increment PC");
        leaves(8'h00, 8'h00, 8'h00, 8'hFD, 5'b00010);     // Chapter 15: the reset took S from 00 to FD
        opcode_cycle(16'hC002,    8'hA9, "LDA #$80");
        next_cycle  (16'hC003, R, 8'h80, "fetch value, increment PC");
        leaves(8'h80, 8'h00, 8'h00, 8'hFD, 5'b10000);     // Chapter 15: the same
        opcode_cycle(16'hC004,    8'h9A, "TXS");
        next_cycle  (16'hC005, R, 8'hBA, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h00, 8'h00, 8'h00, 5'b10000);     // no flag changes
        opcode_cycle(16'hC005,    8'hBA, "TSX");
        next_cycle  (16'hC006, R, 8'h48, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h00, 8'h00, 8'h00, 5'b00010);     // X = 00: Z

        // PHA and PLA. S goes from 00 round to FF, and back.
        opcode_cycle(16'hC006,    8'h48, "PHA");
        next_cycle  (16'hC007, R, 8'hA9, "read next instruction byte (throw it away)");
        next_cycle  (16'h0100, W, 8'h80, "push register on stack, decrement S");
        leaves(8'h80, 8'h00, 8'h00, 8'hFF, 5'b00010);     // no flag changes
        opcode_cycle(16'hC007,    8'hA9, "LDA #0");
        next_cycle  (16'hC008, R, 8'h00, "fetch value, increment PC");
        leaves(8'h00, 8'h00, 8'h00, 8'hFF, 5'b00010);
        opcode_cycle(16'hC009,    8'h48, "PHA");
        next_cycle  (16'hC00A, R, 8'hA9, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FF, W, 8'h00, "push register on stack, decrement S");
        leaves(8'h00, 8'h00, 8'h00, 8'hFE, 5'b00010);
        opcode_cycle(16'hC00A,    8'hA9, "LDA #$41");
        next_cycle  (16'hC00B, R, 8'h41, "fetch value, increment PC");
        leaves(8'h41, 8'h00, 8'h00, 8'hFE, 5'b00000);
        opcode_cycle(16'hC00C,    8'h68, "PLA");
        next_cycle  (16'hC00D, R, 8'h68, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FE, R, 8'h00, "increment S");
        next_cycle  (16'h01FF, R, 8'h00, "pull register from stack");
        leaves(8'h00, 8'h00, 8'h00, 8'hFF, 5'b00010);     // A = 00: Z
        opcode_cycle(16'hC00D,    8'h68, "PLA");
        next_cycle  (16'hC00E, R, 8'hBA, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FF, R, 8'h00, "increment S");
        next_cycle  (16'h0100, R, 8'h80, "pull register from stack");
        leaves(8'h80, 8'h00, 8'h00, 8'h00, 5'b10000);     // A = 80: N
        opcode_cycle(16'hC00E,    8'hBA, "TSX");
        next_cycle  (16'hC00F, R, 8'hA2, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'h00, 8'h00, 8'h00, 5'b00010);

        // JSR and RTS, from an empty stack. outer calls inner.
        opcode_cycle(16'hC00F,    8'hA2, "LDX #$FF");
        next_cycle  (16'hC010, R, 8'hFF, "fetch value, increment PC");
        leaves(8'h80, 8'hFF, 8'h00, 8'h00, 5'b10000);
        opcode_cycle(16'hC011,    8'h9A, "TXS");
        next_cycle  (16'hC012, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h80, 8'hFF, 8'h00, 8'hFF, 5'b10000);
        opcode_cycle(16'hC012,    8'hA9, "LDA #$11");
        next_cycle  (16'hC013, R, 8'h11, "fetch value, increment PC");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFF, 5'b00000);
        opcode_cycle(16'hC014,    8'h20, "JSR outer");
        next_cycle  (16'hC015, R, 8'h06, "fetch low address byte, increment PC");
        next_cycle  (16'h01FF, R, 8'h00, "internal operation (predecrement S?)");
        next_cycle  (16'h01FF, W, 8'hC0, "push PCH on stack, decrement S");
        next_cycle  (16'h01FE, W, 8'h16, "push PCL on stack, decrement S");
        next_cycle  (16'hC016, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFD, 5'b00000);
        opcode_cycle(16'hC106,    8'h48, "PHA");
        next_cycle  (16'hC107, R, 8'h20, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FD, W, 8'h11, "push register on stack, decrement S");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFC, 5'b00000);
        opcode_cycle(16'hC107,    8'h20, "JSR inner");
        next_cycle  (16'hC108, R, 8'h0C, "fetch low address byte, increment PC");
        next_cycle  (16'h01FC, R, 8'h00, "internal operation (predecrement S?)");
        next_cycle  (16'h01FC, W, 8'hC1, "push PCH on stack, decrement S");
        next_cycle  (16'h01FB, W, 8'h09, "push PCL on stack, decrement S");
        next_cycle  (16'hC109, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFA, 5'b00000);
        opcode_cycle(16'hC10C,    8'h48, "PHA");
        next_cycle  (16'hC10D, R, 8'hBA, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FA, W, 8'h11, "push register on stack, decrement S");
        leaves(8'h11, 8'hFF, 8'h00, 8'hF9, 5'b00000);
        opcode_cycle(16'hC10D,    8'hBA, "TSX");
        next_cycle  (16'hC10E, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'hF9, 8'h00, 8'hF9, 5'b10000);     // X = F9: N
        opcode_cycle(16'hC10E,    8'hA9, "LDA #$22");
        next_cycle  (16'hC10F, R, 8'h22, "fetch value, increment PC");
        leaves(8'h22, 8'hF9, 8'h00, 8'hF9, 5'b00000);
        opcode_cycle(16'hC110,    8'h68, "PLA");
        next_cycle  (16'hC111, R, 8'h60, "read next instruction byte (throw it away)");
        next_cycle  (16'h01F9, R, 8'h00, "increment S");
        next_cycle  (16'h01FA, R, 8'h11, "pull register from stack");
        leaves(8'h11, 8'hF9, 8'h00, 8'hFA, 5'b00000);
        opcode_cycle(16'hC111,    8'h60, "RTS");
        next_cycle  (16'hC112, R, 8'h00, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FA, R, 8'h11, "increment S");
        next_cycle  (16'h01FB, R, 8'h09, "pull PCL from stack, increment S");
        next_cycle  (16'h01FC, R, 8'hC1, "pull PCH from stack");
        next_cycle  (16'hC109, R, 8'hC1, "increment PC");
        leaves(8'h11, 8'hF9, 8'h00, 8'hFC, 5'b00000);
        opcode_cycle(16'hC10A,    8'h68, "PLA");
        next_cycle  (16'hC10B, R, 8'h60, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FC, R, 8'hC1, "increment S");
        next_cycle  (16'h01FD, R, 8'h11, "pull register from stack");
        leaves(8'h11, 8'hF9, 8'h00, 8'hFD, 5'b00000);
        opcode_cycle(16'hC10B,    8'h60, "RTS");
        next_cycle  (16'hC10C, R, 8'h48, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FD, R, 8'h11, "increment S");
        next_cycle  (16'h01FE, R, 8'h16, "pull PCL from stack, increment S");
        next_cycle  (16'h01FF, R, 8'hC0, "pull PCH from stack");
        next_cycle  (16'hC016, R, 8'hC1, "increment PC");
        leaves(8'h11, 8'hF9, 8'h00, 8'hFF, 5'b00000);
        opcode_cycle(16'hC017,    8'hBA, "TSX");
        next_cycle  (16'hC018, R, 8'hA2, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFF, 5'b10000);

        // A JSR when S is 00: the two bytes go to $0100 and $01FF.
        opcode_cycle(16'hC018,    8'hA2, "LDX #0");
        next_cycle  (16'hC019, R, 8'h00, "fetch value, increment PC");
        leaves(8'h11, 8'h00, 8'h00, 8'hFF, 5'b00010);
        opcode_cycle(16'hC01A,    8'h9A, "TXS");
        next_cycle  (16'hC01B, R, 8'h20, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'h00, 8'h00, 8'h00, 5'b00010);
        opcode_cycle(16'hC01B,    8'h20, "JSR inner");
        next_cycle  (16'hC01C, R, 8'h0C, "fetch low address byte, increment PC");
        next_cycle  (16'h0100, R, 8'h80, "internal operation (predecrement S?)");
        next_cycle  (16'h0100, W, 8'hC0, "push PCH on stack, decrement S");
        next_cycle  (16'h01FF, W, 8'h1D, "push PCL on stack, decrement S");
        next_cycle  (16'hC01D, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'h00, 8'h00, 8'hFE, 5'b00010);
        opcode_cycle(16'hC10C,    8'h48, "PHA");
        next_cycle  (16'hC10D, R, 8'hBA, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FE, W, 8'h11, "push register on stack, decrement S");
        leaves(8'h11, 8'h00, 8'h00, 8'hFD, 5'b00010);
        opcode_cycle(16'hC10D,    8'hBA, "TSX");
        next_cycle  (16'hC10E, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'hFD, 8'h00, 8'hFD, 5'b10000);
        opcode_cycle(16'hC10E,    8'hA9, "LDA #$22");
        next_cycle  (16'hC10F, R, 8'h22, "fetch value, increment PC");
        leaves(8'h22, 8'hFD, 8'h00, 8'hFD, 5'b00000);
        opcode_cycle(16'hC110,    8'h68, "PLA");
        next_cycle  (16'hC111, R, 8'h60, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FD, R, 8'h11, "increment S");
        next_cycle  (16'h01FE, R, 8'h11, "pull register from stack");
        leaves(8'h11, 8'hFD, 8'h00, 8'hFE, 5'b00000);
        opcode_cycle(16'hC111,    8'h60, "RTS");
        next_cycle  (16'hC112, R, 8'h00, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FE, R, 8'h11, "increment S");
        next_cycle  (16'h01FF, R, 8'h1D, "pull PCL from stack, increment S");
        next_cycle  (16'h0100, R, 8'hC0, "pull PCH from stack");
        next_cycle  (16'hC01D, R, 8'hC1, "increment PC");
        leaves(8'h11, 8'hFD, 8'h00, 8'h00, 5'b00000);
        opcode_cycle(16'hC01E,    8'hBA, "TSX");
        next_cycle  (16'hC01F, R, 8'hA2, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'h00, 8'h00, 8'h00, 5'b00010);

        // A JSR whose last byte is at $C0FF: RTS adds one, and the program
        // goes on at $C100, on the next page.
        opcode_cycle(16'hC01F,    8'hA2, "LDX #$FF");
        next_cycle  (16'hC020, R, 8'hFF, "fetch value, increment PC");
        leaves(8'h11, 8'hFF, 8'h00, 8'h00, 5'b10000);
        opcode_cycle(16'hC021,    8'h9A, "TXS");
        next_cycle  (16'hC022, R, 8'h4C, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFF, 5'b10000);
        opcode_cycle(16'hC022,    8'h4C, "JMP last");
        next_cycle  (16'hC023, R, 8'hFD, "fetch low address byte, increment PC");
        next_cycle  (16'hC024, R, 8'hC0, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFF, 5'b10000);
        opcode_cycle(16'hC0FD,    8'h20, "JSR inner");
        next_cycle  (16'hC0FE, R, 8'h0C, "fetch low address byte, increment PC");
        next_cycle  (16'h01FF, R, 8'h1D, "internal operation (predecrement S?)");
        next_cycle  (16'h01FF, W, 8'hC0, "push PCH on stack, decrement S");
        next_cycle  (16'h01FE, W, 8'hFF, "push PCL on stack, decrement S");
        next_cycle  (16'hC0FF, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFD, 5'b10000);
        opcode_cycle(16'hC10C,    8'h48, "PHA");
        next_cycle  (16'hC10D, R, 8'hBA, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FD, W, 8'h11, "push register on stack, decrement S");
        leaves(8'h11, 8'hFF, 8'h00, 8'hFC, 5'b10000);
        opcode_cycle(16'hC10D,    8'hBA, "TSX");
        next_cycle  (16'hC10E, R, 8'hA9, "read next instruction byte (throw it away)");
        leaves(8'h11, 8'hFC, 8'h00, 8'hFC, 5'b10000);
        opcode_cycle(16'hC10E,    8'hA9, "LDA #$22");
        next_cycle  (16'hC10F, R, 8'h22, "fetch value, increment PC");
        leaves(8'h22, 8'hFC, 8'h00, 8'hFC, 5'b00000);
        opcode_cycle(16'hC110,    8'h68, "PLA");
        next_cycle  (16'hC111, R, 8'h60, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FC, R, 8'hC1, "increment S");
        next_cycle  (16'h01FD, R, 8'h11, "pull register from stack");
        leaves(8'h11, 8'hFC, 8'h00, 8'hFD, 5'b00000);
        opcode_cycle(16'hC111,    8'h60, "RTS");
        next_cycle  (16'hC112, R, 8'h00, "read next instruction byte (throw it away)");
        next_cycle  (16'h01FD, R, 8'h11, "increment S");
        next_cycle  (16'h01FE, R, 8'hFF, "pull PCL from stack, increment S");
        next_cycle  (16'h01FF, R, 8'hC0, "pull PCH from stack");
        next_cycle  (16'hC0FF, R, 8'hC1, "increment PC");
        leaves(8'h11, 8'hFC, 8'h00, 8'hFF, 5'b00000);
        opcode_cycle(16'hC100,    8'h8E, "STX LEDS");
        next_cycle  (16'hC101, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC102, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8000, W, 8'hFC, "write register to effective address");
        leaves(8'h11, 8'hFC, 8'h00, 8'hFF, 5'b00000);

        // Absolute addressing (JMP): the end, twice.
        opcode_cycle(16'hC103,    8'h4C, "JMP done");
        next_cycle  (16'hC104, R, 8'h03, "fetch low address byte, increment PC");
        next_cycle  (16'hC105, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
        leaves(8'h11, 8'hFC, 8'h00, 8'hFF, 5'b00000);
        opcode_cycle(16'hC103,    8'h4C, "JMP done");
        next_cycle  (16'hC104, R, 8'h03, "fetch low address byte, increment PC");
        next_cycle  (16'hC105, R, 8'hC1, "copy low address byte to PCL, fetch high address byte to PCH");
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
            14:      state_name = "PUSH";
            15:      state_name = "STACK_WAIT";
            16:      state_name = "PULL";
            17:      state_name = "PUSH_HIGH";
            18:      state_name = "PULL_HIGH";
            19:      state_name = "RETURN";
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
    // compare A, X, Y, S and the flags with what it should have left.
    always @(negedge clk) begin
        if (step) begin
            if (asked == 7 && cycle < lines) begin
                cycle    = cycle + 1;
                the_byte = write ? data_out : data_in;
                if (first[cycle] && done > 0 && known[done]) begin
                    $display("                         A = %h  X = %h  Y = %h  S = %h   N V D Z C = %b %b %b %b %b",
                             dut.processor.a, dut.processor.x, dut.processor.y, dut.processor.s,
                             flags[4], flags[3], flags[2], flags[1], flags[0]);
                    if (dut.processor.a !== expected_a[done] || dut.processor.x !== expected_x[done]
                     || dut.processor.y !== expected_y[done] || dut.processor.s !== expected_s[done]
                     || flags !== expected_flags[done]) begin
                        errors = errors + 1;
                        $display("                         ^ wrong, expected A = %h  X = %h  Y = %h  S = %h   N V D Z C = %b %b %b %b %b",
                                 expected_a[done], expected_x[done], expected_y[done], expected_s[done],
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
        $display("FAIL: stack, still waiting after 1,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("stack_tb.vcd");
        $dumpvars(0, stack_tb);

        wait (lines > 0 && cycle == lines);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: stack, %0d cycles of %0d instructions as the tables of 64doc say, and A, X, Y, S and the flags after each",
                     lines, instructions);
            $finish;
        end else begin
            $display("FAIL: stack, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
