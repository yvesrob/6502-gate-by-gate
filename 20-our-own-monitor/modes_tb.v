// Chapter 20 uses the modes_tb from chapter 15. This file is a copy of it, unchanged.
// Chapter 15 uses the modes_tb from chapter 11, with two changes, each
// marked "Chapter 15": the wires IRQ and NMI, held at 0, and the seven
// cycles of the reset, which go by before the comparison begins.
// Chapter 11, test bench for the addressing modes, with a program of its own,
// modes.s. Every cycle of the bus is compared with a list written from the
// tables of cycles of 64doc: one line of the list for each line of a table,
// with the words of the table.
`timescale 1ns/1ns
module modes_tb;
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
    computer #(.PROGRAM("modes.hex")) dut (
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
    // next_cycle() each of the others.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:200];
    reg          expected_write   [1:200];
    reg [7:0]    expected_byte    [1:200];
    reg [8*46:1] words            [1:200];
    reg          first            [1:200];
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

    initial begin
        // Immediate addressing.
        opcode_cycle(16'hC000,    8'hA2, "LDX #$40");
        next_cycle  (16'hC001, R, 8'h40, "fetch value, increment PC");
        opcode_cycle(16'hC002,    8'hA0, "LDY #$05");
        next_cycle  (16'hC003, R, 8'h05, "fetch value, increment PC");
        opcode_cycle(16'hC004,    8'hA9, "LDA #$11");
        next_cycle  (16'hC005, R, 8'h11, "fetch value, increment PC");

        // Zero page addressing.
        opcode_cycle(16'hC006,    8'h85, "STA $30");
        next_cycle  (16'hC007, R, 8'h30, "fetch address, increment PC");
        next_cycle  (16'h0030, W, 8'h11, "write register to effective address");
        opcode_cycle(16'hC008,    8'hA4, "LDY $30");
        next_cycle  (16'hC009, R, 8'h30, "fetch address, increment PC");
        next_cycle  (16'h0030, R, 8'h11, "read from effective address");

        // Zero page indexed addressing.
        opcode_cycle(16'hC00A,    8'hA9, "LDA #$22");
        next_cycle  (16'hC00B, R, 8'h22, "fetch value, increment PC");
        opcode_cycle(16'hC00C,    8'h95, "STA $F0,X");
        next_cycle  (16'hC00D, R, 8'hF0, "fetch address, increment PC");
        next_cycle  (16'h00F0, R, 8'h00, "read from address, add index register to it");
        next_cycle  (16'h0030, W, 8'h22, "write to effective address");
        opcode_cycle(16'hC00E,    8'hB4, "LDY $F0,X");
        next_cycle  (16'hC00F, R, 8'hF0, "fetch address, increment PC");
        next_cycle  (16'h00F0, R, 8'h00, "read from address, add index register to it");
        next_cycle  (16'h0030, R, 8'h22, "read from effective address");
        opcode_cycle(16'hC010,    8'h96, "STX $20,Y");
        next_cycle  (16'hC011, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, R, 8'h00, "read from address, add index register to it");
        next_cycle  (16'h0042, W, 8'h40, "write to effective address");
        opcode_cycle(16'hC012,    8'hB6, "LDX $20,Y");
        next_cycle  (16'hC013, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, R, 8'h00, "read from address, add index register to it");
        next_cycle  (16'h0042, R, 8'h40, "read from effective address");

        // Absolute addressing.
        opcode_cycle(16'hC014,    8'h8C, "STY $0300");
        next_cycle  (16'hC015, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC016, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, W, 8'h22, "write register to effective address");
        opcode_cycle(16'hC017,    8'hAD, "LDA $0300");
        next_cycle  (16'hC018, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC019, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, R, 8'h22, "read from effective address");

        // Absolute indexed addressing, with an implied instruction or two.
        opcode_cycle(16'hC01A,    8'hE8, "INX");
        next_cycle  (16'hC01B, R, 8'h9D, "read next instruction byte (throw it away)");
        opcode_cycle(16'hC01B,    8'h9D, "STA $0280,X");
        next_cycle  (16'hC01C, R, 8'h80, "fetch low byte of address, increment PC");
        next_cycle  (16'hC01D, R, 8'h02, "fetch high byte, add index to low byte");
        next_cycle  (16'h02C1, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h02C1, W, 8'h22, "write to effective address");
        opcode_cycle(16'hC01E,    8'hBD, "LDA $0280,X");
        next_cycle  (16'hC01F, R, 8'h80, "fetch low byte of address, increment PC");
        next_cycle  (16'hC020, R, 8'h02, "fetch high byte, add index to low byte");
        next_cycle  (16'h02C1, R, 8'h22, "read from effective address");
        opcode_cycle(16'hC021,    8'h88, "DEY");
        next_cycle  (16'hC022, R, 8'h8E, "read next instruction byte (throw it away)");
        opcode_cycle(16'hC022,    8'h8E, "STX $02F0");
        next_cycle  (16'hC023, R, 8'hF0, "fetch low byte of address, increment PC");
        next_cycle  (16'hC024, R, 8'h02, "fetch high byte of address, increment PC");
        next_cycle  (16'h02F0, W, 8'h41, "write register to effective address");
        opcode_cycle(16'hC025,    8'hB9, "LDA $02CF,Y");
        next_cycle  (16'hC026, R, 8'hCF, "fetch low byte of address, increment PC");
        next_cycle  (16'hC027, R, 8'h02, "fetch high byte, add index to low byte");
        next_cycle  (16'h02F0, R, 8'h41, "read from effective address");
        opcode_cycle(16'hC028,    8'hBE, "LDX $02DF,Y");
        next_cycle  (16'hC029, R, 8'hDF, "fetch low byte of address, increment PC");
        next_cycle  (16'hC02A, R, 8'h02, "fetch high byte, add index to low byte");
        next_cycle  (16'h0200, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h0300, R, 8'h22, "re-read from effective address");

        // An address kept in page zero, at $50 and $51.
        opcode_cycle(16'hC02B,    8'hA9, "LDA #$F0");
        next_cycle  (16'hC02C, R, 8'hF0, "fetch value, increment PC");
        opcode_cycle(16'hC02D,    8'h85, "STA $50");
        next_cycle  (16'hC02E, R, 8'h50, "fetch address, increment PC");
        next_cycle  (16'h0050, W, 8'hF0, "write register to effective address");
        opcode_cycle(16'hC02F,    8'hA9, "LDA #$02");
        next_cycle  (16'hC030, R, 8'h02, "fetch value, increment PC");
        opcode_cycle(16'hC031,    8'h85, "STA $51");
        next_cycle  (16'hC032, R, 8'h51, "fetch address, increment PC");
        next_cycle  (16'h0051, W, 8'h02, "write register to effective address");

        // Indirect indexed addressing: (zp),Y.
        opcode_cycle(16'hC033,    8'hA0, "LDY #$00");
        next_cycle  (16'hC034, R, 8'h00, "fetch value, increment PC");
        opcode_cycle(16'hC035,    8'hB1, "LDA ($50),Y");
        next_cycle  (16'hC036, R, 8'h50, "fetch pointer address, increment PC");
        next_cycle  (16'h0050, R, 8'hF0, "fetch effective address low");
        next_cycle  (16'h0051, R, 8'h02, "fetch effective address high, add Y");
        next_cycle  (16'h02F0, R, 8'h41, "read from effective address");
        opcode_cycle(16'hC037,    8'hA0, "LDY #$10");
        next_cycle  (16'hC038, R, 8'h10, "fetch value, increment PC");
        opcode_cycle(16'hC039,    8'hB1, "LDA ($50),Y");
        next_cycle  (16'hC03A, R, 8'h50, "fetch pointer address, increment PC");
        next_cycle  (16'h0050, R, 8'hF0, "fetch effective address low");
        next_cycle  (16'h0051, R, 8'h02, "fetch effective address high, add Y");
        next_cycle  (16'h0200, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h0300, R, 8'h22, "read from effective address");
        opcode_cycle(16'hC03B,    8'hC8, "INY");
        next_cycle  (16'hC03C, R, 8'h91, "read next instruction byte (throw it away)");
        opcode_cycle(16'hC03C,    8'h91, "STA ($50),Y");
        next_cycle  (16'hC03D, R, 8'h50, "fetch pointer address, increment PC");
        next_cycle  (16'h0050, R, 8'hF0, "fetch effective address low");
        next_cycle  (16'h0051, R, 8'h02, "fetch effective address high, add Y");
        next_cycle  (16'h0201, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h0301, W, 8'h22, "write to effective address");

        // Indexed indirect addressing: (zp,X).
        opcode_cycle(16'hC03E,    8'hA2, "LDX #$10");
        next_cycle  (16'hC03F, R, 8'h10, "fetch value, increment PC");
        opcode_cycle(16'hC040,    8'hA9, "LDA #$01");
        next_cycle  (16'hC041, R, 8'h01, "fetch value, increment PC");
        opcode_cycle(16'hC042,    8'h85, "STA $60");
        next_cycle  (16'hC043, R, 8'h60, "fetch address, increment PC");
        next_cycle  (16'h0060, W, 8'h01, "write register to effective address");
        opcode_cycle(16'hC044,    8'hA9, "LDA #$03");
        next_cycle  (16'hC045, R, 8'h03, "fetch value, increment PC");
        opcode_cycle(16'hC046,    8'h85, "STA $61");
        next_cycle  (16'hC047, R, 8'h61, "fetch address, increment PC");
        next_cycle  (16'h0061, W, 8'h03, "write register to effective address");
        opcode_cycle(16'hC048,    8'hA1, "LDA ($50,X)");
        next_cycle  (16'hC049, R, 8'h50, "fetch pointer address, increment PC");
        next_cycle  (16'h0050, R, 8'hF0, "read from the address, add X to it");
        next_cycle  (16'h0060, R, 8'h01, "fetch effective address low");
        next_cycle  (16'h0061, R, 8'h03, "fetch effective address high");
        next_cycle  (16'h0301, R, 8'h22, "read from effective address");
        opcode_cycle(16'hC04A,    8'hA9, "LDA #$55");
        next_cycle  (16'hC04B, R, 8'h55, "fetch value, increment PC");
        opcode_cycle(16'hC04C,    8'h81, "STA ($50,X)");
        next_cycle  (16'hC04D, R, 8'h50, "fetch pointer address, increment PC");
        next_cycle  (16'h0050, R, 8'hF0, "read from the address, add X to it");
        next_cycle  (16'h0060, R, 8'h01, "fetch effective address low");
        next_cycle  (16'h0061, R, 8'h03, "fetch effective address high");
        next_cycle  (16'h0301, W, 8'h55, "write to effective address");

        // Read-Modify-Write instructions.
        opcode_cycle(16'hC04E,    8'hE6, "INC $30");
        next_cycle  (16'hC04F, R, 8'h30, "fetch address, increment PC");
        next_cycle  (16'h0030, R, 8'h22, "read from effective address");
        next_cycle  (16'h0030, W, 8'h22, "write the value back, do the operation on it");
        next_cycle  (16'h0030, W, 8'h23, "write the new value to effective address");
        opcode_cycle(16'hC050,    8'hD6, "DEC $20,X");
        next_cycle  (16'hC051, R, 8'h20, "fetch address, increment PC");
        next_cycle  (16'h0020, R, 8'h00, "read from address, add index register X to it");
        next_cycle  (16'h0030, R, 8'h23, "read from effective address");
        next_cycle  (16'h0030, W, 8'h23, "write the value back, do the operation on it");
        next_cycle  (16'h0030, W, 8'h22, "write the new value to effective address");
        opcode_cycle(16'hC052,    8'hEE, "INC $0300");
        next_cycle  (16'hC053, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC054, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, R, 8'h22, "read from effective address");
        next_cycle  (16'h0300, W, 8'h22, "write the value back, do the operation on it");
        next_cycle  (16'h0300, W, 8'h23, "write the new value to effective address");
        opcode_cycle(16'hC055,    8'hDE, "DEC $02F0,X");
        next_cycle  (16'hC056, R, 8'hF0, "fetch low byte of address, increment PC");
        next_cycle  (16'hC057, R, 8'h02, "fetch high byte, add index X to low byte");
        next_cycle  (16'h0200, R, 8'h00, "read from effective address, fix high byte");
        next_cycle  (16'h0300, R, 8'h23, "re-read from effective address");
        next_cycle  (16'h0300, W, 8'h23, "write the value back, do the operation on it");
        next_cycle  (16'h0300, W, 8'h22, "write the new value to effective address");
        opcode_cycle(16'hC058,    8'hCA, "DEX");
        next_cycle  (16'hC059, R, 8'hA9, "read next instruction byte (throw it away)");

        // The LEDs read back, and an address where nobody answers.
        opcode_cycle(16'hC059,    8'hA9, "LDA #%101101");
        next_cycle  (16'hC05A, R, 8'h2D, "fetch value, increment PC");
        opcode_cycle(16'hC05B,    8'h8D, "STA LEDS");
        next_cycle  (16'hC05C, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC05D, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8000, W, 8'h2D, "write register to effective address");
        opcode_cycle(16'hC05E,    8'hAE, "LDX LEDS");
        next_cycle  (16'hC05F, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC060, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8000, R, 8'h2D, "read from effective address");
        opcode_cycle(16'hC061,    8'hAC, "LDY NOTHING");
        next_cycle  (16'hC062, R, 8'h01, "fetch low byte of address, increment PC");
        next_cycle  (16'hC063, R, 8'h80, "fetch high byte of address, increment PC");
        next_cycle  (16'h8001, R, 8'h00, "read from effective address");

        // Absolute indirect addressing (JMP), across the end of a page.
        opcode_cycle(16'hC064,    8'hA9, "LDA #<done");
        next_cycle  (16'hC065, R, 8'h74, "fetch value, increment PC");
        opcode_cycle(16'hC066,    8'h8D, "STA $03FF");
        next_cycle  (16'hC067, R, 8'hFF, "fetch low byte of address, increment PC");
        next_cycle  (16'hC068, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h03FF, W, 8'h74, "write register to effective address");
        opcode_cycle(16'hC069,    8'hA9, "LDA #>done");
        next_cycle  (16'hC06A, R, 8'hC0, "fetch value, increment PC");
        opcode_cycle(16'hC06B,    8'h8D, "STA $0300");
        next_cycle  (16'hC06C, R, 8'h00, "fetch low byte of address, increment PC");
        next_cycle  (16'hC06D, R, 8'h03, "fetch high byte of address, increment PC");
        next_cycle  (16'h0300, W, 8'hC0, "write register to effective address");
        opcode_cycle(16'hC06E,    8'h6C, "JMP ($03FF)");
        next_cycle  (16'hC06F, R, 8'hFF, "fetch pointer address low, increment PC");
        next_cycle  (16'hC070, R, 8'h03, "fetch pointer address high, increment PC");
        next_cycle  (16'h03FF, R, 8'h74, "fetch low address to latch");
        next_cycle  (16'h0300, R, 8'hC0, "fetch PCH, copy latch to PCL");

        // Absolute addressing (JMP): the end, twice.
        opcode_cycle(16'hC074,    8'h4C, "JMP done");
        next_cycle  (16'hC075, R, 8'h74, "fetch low address byte, increment PC");
        next_cycle  (16'hC076, R, 8'hC0, "copy low address byte to PCL, fetch high");
        opcode_cycle(16'hC074,    8'h4C, "JMP done");
        next_cycle  (16'hC075, R, 8'h74, "fetch low address byte, increment PC");
        next_cycle  (16'hC076, R, 8'hC0, "copy low address byte to PCL, fetch high");
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

    integer cycle   = 0;
    integer errors  = 0;
    integer asked   = 0;      // Chapter 15: the seven cycles of the reset go by first
    reg [7:0] the_byte;

    // At the end of every cycle, compare the bus with the next line of the list.
    always @(negedge clk) begin
        if (step) begin
            if (asked == 7 && cycle < lines) begin
                cycle    = cycle + 1;
                the_byte = write ? data_out : data_in;
                if (first[cycle]) begin
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
        $display("FAIL: modes, still waiting after 1,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("modes_tb.vcd");
        $dumpvars(0, modes_tb);

        wait (lines > 0 && cycle == lines);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: modes, %0d cycles of %0d instructions, as the tables of 64doc say", lines, instructions);
            $finish;
        end else begin
            $display("FAIL: modes, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
