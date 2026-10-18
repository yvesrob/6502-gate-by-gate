// Chapter 20 uses the interrupts_tb from chapter 15. This file is a copy of it, unchanged.
// Chapter 15, test bench for the interrupts, with a program of its own,
// interrupts.s. Every cycle of the bus is compared with a list written from
// the tables of cycles of 64doc (for the interrupts and the reset, from the
// NESdev wiki), and A, X, Y, S and the six flags with what each instruction
// must leave. The test bench plays a device on IRQ: it raises IRQ at chosen
// cycles, and lets it go back to 0 when the program writes at $8001. It
// raises NMI too, and at the end it presses reset. Where each interrupt must
// come follows from what the processor looks at, during the last cycle of an
// instruction: the wires as they were at the end of the cycle before, and I
// as it is. CLI, SEI and PLP change I after that look; RTI changes it before.
// A taken branch does not look on its third cycle.
`timescale 1ns/1ns
module interrupts_tb;
    reg         clk   = 0;
    reg         reset = 0;
    reg         irq   = 0;
    reg         nmi   = 0;
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
    computer #(.PROGRAM("interrupts.hex")) dut (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .irq      (irq),
        .nmi      (nmi),
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // The RAM starts at zero, as in the chip. The test bench reads the
    // program, to know the bytes that are read for nothing.
    reg [7:0] program [0:16383];
    integer   n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.the_ram.cells[n] = 8'h00;
        end
        $readmemh("interrupts.hex", program);
    end

    function [7:0] code;
        input [15:0] at;
        code = (at >= 16'hC000) ? program[at - 16'hC000] : 8'h00;
    endfunction

    // The list. opcode_cycle() is the first cycle of an instruction, or of an
    // interrupt, and next_cycle() each of the others. When an instruction is
    // written down, the test bench works out what it leaves: A, X, Y, S, and
    // the flags N V D I Z C.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:1000];
    reg          expected_write   [1:1000];
    reg [7:0]    expected_byte    [1:1000];
    reg [8*62:1] words            [1:1000];
    reg          first            [1:1000];
    reg          raise_irq        [1:1000];  // IRQ goes up at the end of this cycle
    reg          raise_nmi        [1:1000];  // NMI goes up at the end of this cycle
    reg          press            [1:1000];  // reset is pressed after this cycle
    reg [7:0]    expected_a       [1:400];
    reg [7:0]    expected_x       [1:400];
    reg [7:0]    expected_y       [1:400];
    reg [7:0]    expected_s       [1:400];
    reg [5:0]    expected_flags   [1:400];
    integer      lines        = 0;
    integer      instructions = 0;
    integer      irqs         = 0;      // interrupts written down in the list
    integer      nmis         = 0;
    integer      breaks       = 0;
    reg          planned      = 0;

    // The processor, as the test bench works it out.
    reg [7:0] a = 0, x = 0, y = 0, s = 0;
    reg       fn = 0, fv = 0, fd = 0, fi = 0, fz = 0, fc = 0;
    reg [7:0] page1 [0:255];
    initial begin
        for (n = 0; n < 256; n = n + 1) page1[n] = 8'h00;
    end

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
            raise_irq[lines]        = 0;
            raise_nmi[lines]        = 0;
            press[lines]            = 0;
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
            raise_irq[lines]        = 0;
            raise_nmi[lines]        = 0;
            press[lines]            = 0;
        end
    endtask

    // What the instruction just written down leaves.
    task leaves;
        begin
            expected_a[instructions]     = a;
            expected_x[instructions]     = x;
            expected_y[instructions]     = y;
            expected_s[instructions]     = s;
            expected_flags[instructions] = {fn, fv, fd, fi, fz, fc};
        end
    endtask

    task nz;
        input [7:0] value;
        begin
            fn = value[7];
            fz = (value == 8'h00);
        end
    endtask

    // P as one byte, with bit 5 at 1 and B as given.
    function [7:0] p;
        input b;
        p = {fn, fv, 1'b1, b, fd, fi, fz, fc};
    endfunction

    task push;
        input [7:0]    the_byte;
        input [8*62:1] the_words;
        begin
            next_cycle({8'h01, s}, W, the_byte, the_words);
            page1[s] = the_byte;
            s        = s - 8'd1;
        end
    endtask

    task pull;
        input  [8*62:1] the_words;
        output [7:0]    the_byte;
        begin
            s        = s + 8'd1;
            the_byte = page1[s];
            next_cycle({8'h01, s}, R, the_byte, the_words);
        end
    endtask

    task stack_read;
        input [8*62:1] the_words;
        begin
            next_cycle({8'h01, s}, R, page1[s], the_words);
        end
    endtask

    // ---- The instructions, as 64doc gives their cycles ----------------------

    // Implied: two cycles. The model changes after.
    task implied;
        input [15:0]   at;
        input [8*62:1] name;
        begin
            opcode_cycle(at, code(at), name);
            next_cycle(at + 16'd1, R, code(at + 16'd1), "read next instruction byte (and throw it away)");
        end
    endtask

    task immediate;
        input [15:0]   at;
        input [8*62:1] name;
        begin
            opcode_cycle(at, code(at), name);
            next_cycle(at + 16'd1, R, code(at + 16'd1), "fetch value, increment PC");
        end
    endtask

    task lda_immediate;
        input [15:0] at;
        input [8*62:1] name;
        begin
            immediate(at, name);
            a = code(at + 16'd1);
            nz(a);
            leaves;
        end
    endtask

    task sta_absolute;
        input [15:0]   at;
        input [8*62:1] name;
        reg   [15:0]   there;
        begin
            there = {code(at + 16'd2), code(at + 16'd1)};
            opcode_cycle(at, code(at), name);
            next_cycle(at + 16'd1, R, code(at + 16'd1), "fetch low byte of address, increment PC");
            next_cycle(at + 16'd2, R, code(at + 16'd2), "fetch high byte of address, increment PC");
            next_cycle(there, W, a, "write register to effective address");
            leaves;
        end
    endtask

    task push_instruction;     // PHA or PHP
        input [15:0]   at;
        input [7:0]    the_byte;
        input [8*62:1] name;
        begin
            implied(at, name);
            push(the_byte, "push register on stack, decrement S");
            leaves;
        end
    endtask

    task pull_instruction;     // PLA or PLP: what is pulled comes back in pulled
        input  [15:0]   at;
        input  [8*62:1] name;
        output [7:0]    pulled;
        begin
            implied(at, name);
            stack_read("increment S");
            pull("pull register from stack", pulled);
        end
    endtask

    task pla;
        input [15:0] at;
        begin
            pull_instruction(at, "PLA", a);
            nz(a);
            leaves;
        end
    endtask

    task plp;
        input [15:0] at;
        reg   [7:0]  q;
        begin
            pull_instruction(at, "PLP", q);
            {fn, fv, fd, fi, fz, fc} = {q[7], q[6], q[3], q[2], q[1], q[0]};
            leaves;
        end
    endtask

    // A branch: taken or not, and on the same page or not.
    task branch;
        input [15:0]   at;
        input          taken;
        input [8*62:1] name;
        reg   [15:0]   after;
        reg   [15:0]   target;
        reg   [7:0]    offset;
        begin
            after  = at + 16'd2;
            offset = code(at + 16'd1);
            target = after + {{8{offset[7]}}, offset};
            opcode_cycle(at, code(at), name);
            next_cycle(at + 16'd1, R, code(at + 16'd1), "fetch operand, increment PC");
            if (taken) begin
                next_cycle(after, R, code(after), "Fetch opcode of next instruction, If branch is taken, add operand to PCL.");
                if (target[15:8] != after[15:8]) begin
                    next_cycle({after[15:8], target[7:0]}, R, code({after[15:8], target[7:0]}),
                               "Fetch opcode of next instruction. Fix PCH.");
                end
            end
            leaves;
        end
    endtask

    task jmp_absolute;
        input [15:0] at;
        begin
            opcode_cycle(at, code(at), "JMP");
            next_cycle(at + 16'd1, R, code(at + 16'd1), "fetch low address byte, increment PC");
            next_cycle(at + 16'd2, R, code(at + 16'd2), "copy low address byte to PCL, fetch high address byte to PCH");
            leaves;
        end
    endtask

    // An interrupt, which takes the place of the opcode at the address at.
    task interrupt;
        input [15:0] at;
        input        is_nmi;
        begin
            opcode_cycle(at, code(at), is_nmi ? "NMI: fetch opcode (and discard it)" : "IRQ: fetch opcode (and discard it)");
            next_cycle(at, R, code(at), "read next instruction byte (the same: PC does not move)");
            push(at[15:8], "push PCH on stack, decrement S");
            push(at[7:0],  "push PCL on stack, decrement S");
            push(p(0),     "push P on stack (with B flag clear), decrement S");
            next_cycle(is_nmi ? 16'hFFFA : 16'hFFFE, R, code(is_nmi ? 16'hFFFA : 16'hFFFE), "fetch PCL, set I flag");
            fi = 1;
            next_cycle(is_nmi ? 16'hFFFB : 16'hFFFF, R, code(is_nmi ? 16'hFFFB : 16'hFFFF), "fetch PCH");
            leaves;
            if (is_nmi) nmis = nmis + 1; else irqs = irqs + 1;
        end
    endtask

    task brk;
        input [15:0] at;
        reg   [15:0] back;
        begin
            back = at + 16'd2;
            opcode_cycle(at, code(at), "BRK");
            next_cycle(at + 16'd1, R, code(at + 16'd1), "read next instruction byte (and throw it away), increment PC");
            push(back[15:8], "push PCH on stack, decrement S");
            push(back[7:0],  "push PCL on stack, decrement S");
            push(p(1),       "push P on stack (with B flag set), decrement S");
            next_cycle(16'hFFFE, R, code(16'hFFFE), "fetch PCL");
            fi = 1;
            next_cycle(16'hFFFF, R, code(16'hFFFF), "fetch PCH");
            leaves;
            breaks = breaks + 1;
        end
    endtask

    task rti;
        input [15:0] at;
        reg   [7:0]  q;
        reg   [7:0]  low_byte;
        reg   [7:0]  high_byte;
        begin
            opcode_cycle(at, code(at), "RTI");
            next_cycle(at + 16'd1, R, code(at + 16'd1), "read next instruction byte (and throw it away)");
            stack_read("increment S");
            pull("pull P from stack, increment S", q);
            {fn, fv, fd, fi, fz, fc} = {q[7], q[6], q[3], q[2], q[1], q[0]};
            pull("pull PCL from stack, increment S", low_byte);
            pull("pull PCH from stack", high_byte);
            leaves;
        end
    endtask

    // The handler of IRQ and BRK, at $C11B. For an IRQ it stores at $8001,
    // and the test bench lets IRQ go back to 0 then. again: 1 to raise IRQ
    // once more during the first PLA, after the store.
    task irq_handler;
        input from_brk;
        input again;
        reg [15:0] there;
        begin
            push_instruction(16'hC11B, a, "PHA");
            implied(16'hC11C, "TXA");
            a = x;
            nz(a);
            leaves;
            push_instruction(16'hC11D, a, "PHA");
            implied(16'hC11E, "TSX");
            x = s;
            nz(x);
            leaves;
            there = 16'h0103 + x;
            opcode_cycle(16'hC11F, 8'hBD, "LDA $0103,X");
            next_cycle(16'hC120, R, 8'h03, "fetch low byte of address, increment PC");
            next_cycle(16'hC121, R, 8'h01, "fetch high byte of address, add index register to low address byte");
            next_cycle(there, R, page1[there[7:0]], "read from effective address");
            a = page1[there[7:0]];
            nz(a);
            leaves;
            immediate(16'hC122, "AND #%00010000");
            a = a & 8'h10;
            nz(a);
            leaves;
            branch(16'hC124, from_brk, "BNE $C129");
            if (!from_brk) begin
                sta_absolute(16'hC126, "STA $8001");
            end
            pla(16'hC129);
            if (again) raise_irq[lines - 3] = 1;
            implied(16'hC12A, "TAX");
            x = a;
            nz(x);
            leaves;
            pla(16'hC12B);
            rti(16'hC12C);
        end
    endtask

    // The handler of NMI, at $C12D: it shows P on the LEDs.
    task nmi_handler;
        begin
            push_instruction(16'hC12D, a, "PHA");
            push_instruction(16'hC12E, p(1), "PHP");
            pla(16'hC12F);
            sta_absolute(16'hC130, "STA $8000");
            pla(16'hC133);
            rti(16'hC134);
        end
    endtask

    // The seven cycles of the reset, from pc: nothing is written.
    task reset_sequence;
        input [15:0] at;
        begin
            opcode_cycle(at, code(at), "RESET: the byte at pc, for nothing");
            next_cycle(at, R, code(at), "the same byte, again");
            stack_read("the stack, read: a reset writes nothing");
            s = s - 8'd1;
            stack_read("the stack, read: a reset writes nothing");
            s = s - 8'd1;
            stack_read("the stack, read: a reset writes nothing");
            s = s - 8'd1;
            next_cycle(16'hFFFC, R, code(16'hFFFC), "fetch PCL, set I flag");
            fi = 1;
            next_cycle(16'hFFFD, R, code(16'hFFFD), "fetch PCH");
            leaves;
        end
    endtask

    reg [7:0] scratch;
    initial begin
        #1;
        // Switched on: the reset, from pc = 0000.
        reset_sequence(16'h0000);

        // P as one byte.
        immediate(16'hC000, "LDX #$FF");  x = 8'hFF; nz(x); leaves;
        implied(16'hC002, "TXS");         s = x; leaves;
        implied(16'hC003, "SEC");         fc = 1; leaves;
        implied(16'hC004, "SED");         fd = 1; leaves;
        lda_immediate(16'hC005, "LDA #$80");
        push_instruction(16'hC007, p(1), "PHP");
        pla(16'hC008);
        lda_immediate(16'hC009, "LDA #$FF");
        push_instruction(16'hC00B, a, "PHA");
        plp(16'hC00C);
        push_instruction(16'hC00D, p(1), "PHP");
        pla(16'hC00E);
        lda_immediate(16'hC00F, "LDA #0");
        push_instruction(16'hC011, a, "PHA");
        plp(16'hC012);
        push_instruction(16'hC013, p(1), "PHP");
        pla(16'hC014);

        // IRQ refused while I is 1; served one instruction after CLI, then
        // once more at once after RTI.
        implied(16'hC015, "SEI");         fi = 1; leaves;
        implied(16'hC016, "NOP");         raise_irq[lines - 1] = 1; leaves;
        implied(16'hC017, "NOP");         leaves;
        implied(16'hC018, "NOP");         leaves;
        implied(16'hC019, "CLI");         fi = 0; leaves;
        lda_immediate(16'hC01A, "LDA #1");
        interrupt(16'hC01C, 0);
        irq_handler(0, 1);
        interrupt(16'hC01C, 0);
        irq_handler(0, 0);
        sta_absolute(16'hC01C, "STA $8000");

        // SEI, with IRQ raised at the end of its first cycle.
        implied(16'hC01F, "SEI");         raise_irq[lines - 1] = 1; fi = 1; leaves;
        interrupt(16'hC020, 0);
        irq_handler(0, 0);
        lda_immediate(16'hC020, "LDA #2");
        sta_absolute(16'hC022, "STA $8000");

        // PLP takes I to 0 while IRQ asks.
        lda_immediate(16'hC025, "LDA #0");
        push_instruction(16'hC027, a, "PHA");
        raise_irq[lines - 2] = 1;
        plp(16'hC028);
        lda_immediate(16'hC029, "LDA #3");
        interrupt(16'hC02B, 0);
        irq_handler(0, 0);
        sta_absolute(16'hC02B, "STA $8000");

        // The branches.
        branch(16'hC02E, 1, "BCC $C031");
        raise_irq[lines - 2] = 1;               // the end of its first cycle
        interrupt(16'hC031, 0);
        irq_handler(0, 0);
        lda_immediate(16'hC031, "LDA #4");
        sta_absolute(16'hC033, "STA $8000");
        branch(16'hC036, 1, "BCC $C039");
        raise_irq[lines - 1] = 1;               // the end of its second cycle
        lda_immediate(16'hC039, "LDA #5");
        interrupt(16'hC03B, 0);
        irq_handler(0, 0);
        sta_absolute(16'hC03B, "STA $8000");
        branch(16'hC03E, 0, "BCS $C042");
        raise_irq[lines - 1] = 1;               // the end of its first cycle
        interrupt(16'hC040, 0);
        irq_handler(0, 0);
        lda_immediate(16'hC040, "LDA #6");
        sta_absolute(16'hC042, "STA $8000");
        jmp_absolute(16'hC045);
        branch(16'hC0FC, 1, "BCC $C100");
        raise_irq[lines - 1] = 1;               // the end of its third cycle
        interrupt(16'hC100, 0);
        irq_handler(0, 0);
        lda_immediate(16'hC100, "LDA #7");
        sta_absolute(16'hC102, "STA $8000");

        // BRK.
        brk(16'hC105);
        irq_handler(1, 0);
        lda_immediate(16'hC107, "LDA #8");
        sta_absolute(16'hC109, "STA $8000");

        // NMI while I is 1, then while I is 0.
        implied(16'hC10C, "SEI");         fi = 1; leaves;
        implied(16'hC10D, "NOP");         raise_nmi[lines - 1] = 1; leaves;
        interrupt(16'hC10E, 1);
        nmi_handler;
        implied(16'hC10E, "NOP");         leaves;
        implied(16'hC10F, "CLI");         fi = 0; leaves;
        implied(16'hC110, "NOP");         raise_nmi[lines - 1] = 1; leaves;
        interrupt(16'hC111, 1);
        nmi_handler;
        implied(16'hC111, "NOP");         leaves;

        // IRQ and NMI together.
        implied(16'hC112, "NOP");         raise_irq[lines - 1] = 1; raise_nmi[lines - 1] = 1; leaves;
        interrupt(16'hC113, 1);
        nmi_handler;
        interrupt(16'hC113, 0);
        irq_handler(0, 0);
        lda_immediate(16'hC113, "LDA #9");
        sta_absolute(16'hC115, "STA $8000");
        jmp_absolute(16'hC118);
        jmp_absolute(16'hC118);
        press[lines] = 1;

        // The reset, from pc = C118, and the program from the start again.
        reset_sequence(16'hC118);
        immediate(16'hC000, "LDX #$FF");  x = 8'hFF; nz(x); leaves;
        implied(16'hC002, "TXS");         s = x; leaves;
        implied(16'hC003, "SEC");         fc = 1; leaves;
        planned = 1;
    end

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
            20:      state_name = "PUSH_STATUS";
            21:      state_name = "PULL_STATUS";
            22:      state_name = "VECTOR";
            default: state_name = "?";
        endcase
    end

    // The six flags of the processor, in the order the 6502 prints them.
    wire [5:0] flags;
    assign flags = {dut.processor.negative, dut.processor.overflow, dut.processor.decimal,
                    dut.processor.interrupt_disable, dut.processor.zero, dut.processor.carry};

    integer cycle    = 0;
    integer done     = 0;       // instructions finished so far
    integer errors   = 0;
    integer heard    = 0;       // stores at $8001
    reg     pressing = 0;
    reg [7:0] the_byte;

    // At the end of every cycle, compare the bus with the next line of the
    // list. When a new instruction begins, the one before it has finished:
    // compare A, X, Y, S and the flags with what it should have left.
    always @(negedge clk) begin
        if (step & ~reset & planned & (cycle < lines)) begin
            cycle    = cycle + 1;
            the_byte = write ? data_out : data_in;
            if (first[cycle] && done > 0) begin
                $display("                         A = %h  X = %h  Y = %h  S = %h   N V D I Z C = %b %b %b %b %b %b",
                         dut.processor.a, dut.processor.x, dut.processor.y, dut.processor.s,
                         flags[5], flags[4], flags[3], flags[2], flags[1], flags[0]);
                if (dut.processor.a !== expected_a[done] || dut.processor.x !== expected_x[done]
                 || dut.processor.y !== expected_y[done] || dut.processor.s !== expected_s[done]
                 || flags !== expected_flags[done]) begin
                    errors = errors + 1;
                    $display("                         ^ wrong, expected A = %h  X = %h  Y = %h  S = %h   N V D I Z C = %b %b %b %b %b %b",
                             expected_a[done], expected_x[done], expected_y[done], expected_s[done],
                             expected_flags[done][5], expected_flags[done][4], expected_flags[done][3],
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
            // The device: IRQ goes up when the list says so, and back to 0
            // when the program stores at $8001. NMI goes up when the list says
            // so, and back to 0 at the next cycle. The processor sees them at
            // the next tick, the end of this cycle.
            if (nmi) nmi = 0;
            if (raise_irq[cycle]) begin
                irq = 1;
                $display("           IRQ goes up at the end of this cycle");
            end
            if (raise_nmi[cycle]) begin
                nmi = 1;
                $display("           NMI goes up at the end of this cycle");
            end
            if (write && address == 16'h8001) begin
                irq   = 0;
                heard = heard + 1;
                $display("           the device has been told: IRQ goes back to 0 at the end of this cycle");
            end
            if (press[cycle]) pressing = 1;
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
        #60000;
        $display("FAIL: interrupts, still waiting after 6,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("interrupts_tb.vcd");
        $dumpvars(0, interrupts_tb);

        wait (pressing);
        @(posedge clk);
        #1 reset = 1;
        $display("           reset pressed, then let go");
        repeat (3) @(posedge clk);
        #1 reset = 0;

        wait (planned && cycle == lines);
        @(negedge clk);
        if (heard != irqs) begin
            errors = errors + 1;
            $display("wrong: %0d stores at $8001 for %0d IRQs", heard, irqs);
        end

        if (errors == 0) begin
            $display("PASS: interrupts, %0d cycles of %0d instructions and interrupts as 64doc says, %0d IRQs, %0d NMIs, %0d BRK, 2 resets, and A, X, Y, S and the six flags after each",
                     lines, instructions, irqs, nmis, breaks);
            $finish;
        end else begin
            $display("FAIL: interrupts, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
