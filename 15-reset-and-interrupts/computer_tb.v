// Chapter 15, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program, walk.s, from
// the reset on. It plays button S2: it raises NMI at chosen cycles, and it
// knows, from the documents, after which instruction the interrupt must
// come. Then it plays button S1, in the middle of the handler. It follows the
// program on its own: A, X, S, the flags, the stack, and the six LEDs.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         reset = 0;
    reg         nmi   = 0;
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
        .irq      (1'b0),       // nothing asks for IRQ in this program
        .nmi      (nmi),        // button S2, played by the test bench
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // In the chip the RAM starts at zero (we measured it in chapter 8); in
    // the simulator it starts unknown. The test bench does what the chip does.
    // It also reads the program, to know the opcodes that an interrupt reads
    // for nothing, and the vectors.
    reg [7:0] program [0:16383];
    integer   n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.the_ram.cells[n] = 8'h00;
        end
        $readmemh("rom.hex", program);
    end

    // The processor, as the test bench works it out while it writes down the
    // list. V and D stay 0 in walk.s.
    reg [7:0] a = 0;
    reg [7:0] x = 0;
    reg [7:0] s = 0;
    reg [5:0] lit    = 0;       // what the LEDs show
    reg       n_flag = 0;
    reg       z_flag = 0;
    reg       c_flag = 0;
    reg       i_flag = 0;
    reg [7:0] page1 [0:255];    // the stack, as the program fills it
    initial begin
        for (n = 0; n < 256; n = n + 1) page1[n] = 8'h00;
    end

    // What the bus of a 6502 shows while it runs our program, worked out from
    // the tables of cycles of 64doc (for the NMI and the reset, from the
    // NESdev wiki): the address, whether the processor writes, and the byte.
    // And what the test bench does at the end of some cycles: raise NMI, let
    // it go back to 0, press S1.
    localparam R = 0;       // the processor reads
    localparam W = 1;       // the processor writes

    reg [15:0]   expected_address [1:3000];
    reg          expected_write   [1:3000];
    reg [7:0]    expected_byte    [1:3000];
    reg          shown            [1:3000];   // 1: print this cycle
    reg          raise            [1:3000];   // NMI goes from 0 to 1 at the end of this cycle
    reg          lower            [1:3000];   // NMI goes back to 0
    reg          press            [1:3000];   // S1 is pressed after this cycle
    reg          deepest          [1:3000];   // print the stack after this cycle
    reg [8*40:1] comment          [1:3000];
    integer      lines    = 0;      // how many lines the list holds
    integer      printing = 0;      // 1: the lines written down now will be printed
    integer      handlers = 0;      // how many NMI handlers are under way, one inside the other
    integer      writes   = 0;      // how many bytes the list stores at $8000
    reg          stopped  = 0;      // S1 has been pressed: what was under way stops
    reg          planned  = 0;      // the list is written

    task bus;
        input [15:0]   the_address;
        input          the_write;
        input [7:0]    the_byte;
        input [8*40:1] the_comment;
        begin
            lines                   = lines + 1;
            expected_address[lines] = the_address;
            expected_write[lines]   = the_write;
            expected_byte[lines]    = the_byte;
            shown[lines]            = printing;
            raise[lines]            = 0;
            lower[lines]            = 0;
            press[lines]            = 0;
            deepest[lines]          = 0;
            comment[lines]          = the_comment;
            if (the_write && the_address == 16'h8000) writes = writes + 1;
        end
    endtask

    // A byte of the program, at its address.
    function [7:0] code;
        input [15:0] at;
        code = program[at - 16'hC000];
    endfunction

    // The stack. To push is to write at $0100 + S, and S moves down. To pull,
    // S moves up, and the byte is read there. A read for nothing finds what
    // the stack holds.
    task push;
        input [7:0]    the_byte;
        input [8*40:1] the_comment;
        begin
            bus({8'h01, s}, W, the_byte, the_comment);
            page1[s] = the_byte;
            s        = s - 8'd1;
        end
    endtask

    task pull;
        input  [8*40:1] the_comment;
        output [7:0]    the_byte;
        begin
            s        = s + 8'd1;
            the_byte = page1[s];
            bus({8'h01, s}, R, the_byte, the_comment);
        end
    endtask

    task stack_for_nothing;
        input [8*40:1] the_comment;
        begin
            bus({8'h01, s}, R, page1[s], the_comment);
        end
    endtask

    // N and Z, from a byte that a register gets.
    task flags_of;
        input [7:0] value;
        begin
            n_flag = value[7];
            z_flag = (value == 8'h00);
        end
    endtask

    // The seven cycles of the reset, from pc: those of an interrupt, but
    // nothing is written. S moves down by three, and I is set.
    task reset_sequence;
        input [15:0] at;
        input [7:0]  there;     // the byte at pc
        begin
            bus(at, R, there,   "RESET: pc, read for nothing");
            bus(at, R, there,   "  pc again, for nothing");
            stack_for_nothing(  "  the stack, read: no write");
            s = s - 8'd1;
            stack_for_nothing(  "  the stack, read: no write");
            s = s - 8'd1;
            stack_for_nothing(  "  the stack, read: no write");
            s = s - 8'd1;
            bus(16'hFFFC, R, code(16'hFFFC), "  the reset vector, low byte");
            i_flag = 1;
            bus(16'hFFFD, R, code(16'hFFFD), "  the reset vector, high byte");
        end
    endtask

    // The seven cycles of an NMI, which takes the place of the opcode at the
    // address at. P goes onto the stack with B at 0, bit 5 at 1.
    task nmi_sequence;
        input [15:0] at;
        begin
            bus(at, R, code(at), "NMI: the opcode, which must wait");
            lower[lines] = 1;
            bus(at, R, code(at), "  the same byte, again, for nothing");
            push(at[15:8],       "  pc, high byte, pushed");
            push(at[7:0],        "  pc, low byte, pushed");
            push({n_flag, 1'b0, 1'b1, 1'b0, 1'b0, i_flag, z_flag, c_flag},
                                 "  P, pushed, with B at 0");
            bus(16'hFFFA, R, code(16'hFFFA), "  the NMI vector, low byte");
            i_flag = 1;
            bus(16'hFFFB, R, code(16'hFFFB), "  the NMI vector, high byte");
        end
    endtask

    // JSR pause, at the address at: six cycles.
    task call;
        input [15:0] at;
        reg   [15:0] last;
        begin
            last = at + 16'd2;
            bus(at,         R, 8'h20, "JSR pause");
            bus(at + 16'd1, R, 8'h13, "  the address, low byte");
            stack_for_nothing(        "  the stack, read for nothing");
            push(last[15:8],          "  pc, high byte, pushed");
            push(last[7:0],           "  pc, low byte, pushed");
            bus(last,       R, 8'hC0, "  the address, high byte");
        end
    endtask

    // RTS, at the end of pause: back after the JSR.
    task come_back;
        reg [7:0] low_byte;
        reg [7:0] high_byte;
        begin
            bus(16'hC018, R, 8'h60, "RTS");
            bus(16'hC019, R, 8'h48, "  the next byte, not used");
            stack_for_nothing(      "  the stack, read for nothing");
            pull(                   "  pc, low byte, pulled", low_byte);
            pull(                   "  pc, high byte, pulled", high_byte);
            bus({high_byte, low_byte}, R, 8'hC0, "  the last byte of the JSR, again");
        end
    endtask

    // RTI, at the end of nmi: P and pc come back from the stack, and the
    // program goes on at pc, without one more cycle.
    task return_from_interrupt;
        reg [7:0] p;
        reg [7:0] low_byte;
        reg [7:0] high_byte;
        begin
            bus(16'hC02F, R, 8'h40, "RTI");
            bus(16'hC030, R, 8'h00, "  the next byte, not used");
            stack_for_nothing(      "  the stack, read for nothing");
            pull(                   "  P, pulled", p);
            n_flag = p[7];
            i_flag = p[2];
            z_flag = p[1];
            c_flag = p[0];
            pull(                   "  pc, low byte, pulled", low_byte);
            pull(                   "  pc, high byte, pulled", high_byte);
        end
    endtask

    // STA LEDS, at the address at.
    task store;
        input [15:0]   at;
        input [8*40:1] the_comment;
        begin
            bus(at,         R, 8'h8D, "STA $8000");
            bus(at + 16'd1, R, 8'h00, "  the address, low byte");
            bus(at + 16'd2, R, 8'h80, "  the address, high byte");
            bus(16'h8000,   W, a,     the_comment);
            lit = a[5:0];
        end
    endtask

    // pause, called by the JSR at the address at: LDX #5, five rounds of DEX
    // and BNE, RTS. On one round an NMI comes, raised at the end of the cycle
    // that where says:
    //   1  the first cycle of DEX: the NMI comes after that DEX;
    //   2  the first cycle of BNE: it comes after that BNE;
    //   3  the second cycle of BNE, which is taken: a 6502 does not look on
    //      the third cycle of a taken branch, so it comes after the next DEX;
    //   4  no NMI: S1 is pressed after the second cycle of DEX.
    // inner_where and inner_round say the same for the pause of the handler.
    task automatic pause;
        input [15:0]  at;
        input integer where;
        input integer round;
        input integer inner_where;
        input integer inner_round;
        integer       lap;
        reg           after_dex;
        begin
            call(at);
            bus(16'hC013, R, 8'hA2, "LDX #5");
            bus(16'hC014, R, 8'h05, "  the value");
            if (handlers == 2) deepest[lines] = 1;
            x = 8'h05;
            flags_of(x);
            after_dex = 0;
            for (lap = 1; lap <= 5 && !stopped; lap = lap + 1) begin
                bus(16'hC015, R, 8'hCA, "DEX");
                if (lap == round && where == 1) raise[lines] = 1;
                bus(16'hC016, R, 8'hD0, "  the next byte, not used");
                if (lap == round && where == 4) begin
                    press[lines] = 1;
                    stopped      = 1;
                end
                x = x - 8'd1;
                flags_of(x);
                if (!stopped && ((lap == round && where == 1) || after_dex)) begin
                    nmi_sequence(16'hC016);
                    nmi_handler(inner_where, inner_round);
                    after_dex = 0;
                end
                if (!stopped) begin
                    bus(16'hC016, R, 8'hD0, "BNE $C015");
                    if (lap == round && where == 2) raise[lines] = 1;
                    bus(16'hC017, R, 8'hFD, "  how far: FD, back 3");
                    if (lap == round && where == 3) begin
                        raise[lines] = 1;
                        after_dex    = 1;
                    end
                    if (!z_flag) begin
                        bus(16'hC018, R, 8'h60, "  the next opcode, for nothing");
                    end
                    if (lap == round && where == 2) begin
                        nmi_sequence(z_flag ? 16'hC018 : 16'hC015);
                        nmi_handler(inner_where, inner_round);
                    end
                end
            end
            if (!stopped) come_back;
        end
    endtask

    // nmi, the handler of button S2. Its pause may have an NMI of its own.
    task automatic nmi_handler;
        input integer where;
        input integer round;
        begin
            handlers = handlers + 1;
            bus(16'hC019, R, 8'h48, "PHA");
            bus(16'hC01A, R, 8'h8A, "  the next byte, not used");
            push(a,                 "  A, pushed");
            bus(16'hC01A, R, 8'h8A, "TXA");
            bus(16'hC01B, R, 8'h48, "  the next byte, not used");
            a = x;
            flags_of(a);
            bus(16'hC01B, R, 8'h48, "PHA");
            bus(16'hC01C, R, 8'hAD, "  the next byte, not used");
            push(a,                 "  X, pushed");
            bus(16'hC01C, R, 8'hAD, "LDA $8000");
            bus(16'hC01D, R, 8'h00, "  the address, low byte");
            bus(16'hC01E, R, 8'h80, "  the address, high byte");
            a = {2'b00, lit};
            bus(16'h8000, R, a,     "  the LEDs, read back");
            flags_of(a);
            bus(16'hC01F, R, 8'h48, "PHA");
            bus(16'hC020, R, 8'hA9, "  the next byte, not used");
            push(a,                 "  the LEDs, pushed");
            bus(16'hC020, R, 8'hA9, "LDA #%111111");
            bus(16'hC021, R, 8'h3F, "  the value");
            a = 8'h3F;
            flags_of(a);
            store(16'hC022,         "  the six LEDs");
            pause(16'hC025, where, round, 0, 0);
            if (!stopped) begin
                bus(16'hC028, R, 8'h68, "PLA");
                bus(16'hC029, R, 8'h8D, "  the next byte, not used");
                stack_for_nothing(      "  the stack, read for nothing");
                pull(                   "  the LEDs, pulled", a);
                flags_of(a);
                store(16'hC029,         "  what the LEDs showed, back");
                bus(16'hC02C, R, 8'h68, "PLA");
                bus(16'hC02D, R, 8'hAA, "  the next byte, not used");
                stack_for_nothing(      "  the stack, read for nothing");
                pull(                   "  X, pulled", a);
                flags_of(a);
                bus(16'hC02D, R, 8'hAA, "TAX");
                bus(16'hC02E, R, 8'h68, "  the next byte, not used");
                x = a;
                flags_of(x);
                bus(16'hC02E, R, 8'h68, "PLA");
                bus(16'hC02F, R, 8'h40, "  the next byte, not used");
                stack_for_nothing(      "  the stack, read for nothing");
                pull(                   "  A, pulled", a);
                flags_of(a);
                return_from_interrupt;
            end
            handlers = handlers - 1;
        end
    endtask

    // One step of the light: STA, the pause, ASL, CMP, BNE. The NMI of the
    // pause is described by where and round, as above. late: 1 to raise NMI
    // at the end of the last cycle of ASL, one cycle too late for it to come
    // after ASL: it comes after CMP, before BNE, and its handler has a second
    // NMI in its pause.
    task automatic light_step;
        input integer where;
        input integer round;
        input integer inner_where;
        input integer inner_round;
        input integer late;
        reg   [7:0]   difference;
        begin
            store(16'hC005, "  A, on its way to the LEDs");
            pause(16'hC008, where, round, inner_where, inner_round);
            if (!stopped) begin
                bus(16'hC00B, R, 8'h0A, "ASL A");
                bus(16'hC00C, R, 8'hC9, "  the next byte, not used");
                if (late) raise[lines] = 1;
                c_flag = a[7];
                a      = a << 1;
                flags_of(a);
                bus(16'hC00C, R, 8'hC9, "CMP #%1000000");
                bus(16'hC00D, R, 8'h40, "  the value");
                difference = a - 8'h40;
                c_flag     = (a >= 8'h40);
                n_flag     = difference[7];
                z_flag     = (a == 8'h40);
                if (late) begin
                    nmi_sequence(16'hC00E);
                    nmi_handler(1, 2);
                end
                bus(16'hC00E, R, 8'hD0, "BNE $C005");
                bus(16'hC00F, R, 8'hF5, "  how far: F5, back 11");
                if (!z_flag) begin
                    bus(16'hC010, R, 8'h4C, "  the next opcode, for nothing");
                end else begin
                    bus(16'hC010, R, 8'h4C, "JMP $C003");
                    bus(16'hC011, R, 8'h03, "  the address, low byte");
                    bus(16'hC012, R, 8'hC0, "  the address, high byte");
                end
            end
        end
    endtask

    task start;
        begin
            bus(16'hC000, R, 8'hA2, "LDX #$FF");
            bus(16'hC001, R, 8'hFF, "  the value");
            x = 8'hFF;
            flags_of(x);
            bus(16'hC002, R, 8'h9A, "TXS");
            bus(16'hC003, R, 8'hA9, "  the next byte, not used");
            s = x;
        end
    endtask

    task light_one;
        begin
            bus(16'hC003, R, 8'hA9, "LDA #%000001");
            bus(16'hC004, R, 8'h01, "  the value");
            a = 8'h01;
            flags_of(a);
        end
    endtask

    // The whole list, written down before the processor starts.
    integer here;
    initial begin
        #1;
        // Switched on: the reset, from pc = 0000, where the RAM holds 00.
        printing = 1;
        reset_sequence(16'h0000, 8'h00);
        start;
        light_one;
        printing = 0;
        // The first round of the light, with five NMIs.
        light_step(0, 0, 0, 0, 0);          // LED 1: no NMI
        light_step(1, 3, 0, 0, 0);          // LED 2: raised in the first cycle of the third DEX
        light_step(3, 2, 0, 0, 0);          // LED 3: raised in the second cycle of the second BNE
        light_step(2, 2, 0, 0, 0);          // LED 4: raised in the first cycle of the second BNE
        light_step(0, 0, 0, 0, 0);          // LED 5: no NMI
        light_step(0, 0, 0, 0, 1);          // LED 6: raised one cycle too late for ASL, and a second one
        // The second round: in the pause of LED 1, an NMI after the first DEX;
        // in the pause of its handler, S1 is pressed after the second DEX.
        light_one;
        light_step(1, 1, 4, 2, 0);
        stopped = 0;
        // The reset, from pc = C016, where the processor was.
        printing = 1;
        reset_sequence(16'hC016, 8'hD0);
        start;
        light_one;
        printing = 0;
        // A whole round again, then the first LED of the next one.
        light_step(0, 0, 0, 0, 0);
        light_step(0, 0, 0, 0, 0);
        light_step(0, 0, 0, 0, 0);
        light_step(0, 0, 0, 0, 0);
        light_step(0, 0, 0, 0, 0);
        light_step(0, 0, 0, 0, 0);
        light_one;
        store(16'hC005, "  A, on its way to the LEDs");
        // Print the cycles around each NMI: four before the cycle where it
        // goes up, and on to the end of the sequence; and each RTI.
        for (n = 1; n <= lines; n = n + 1) begin
            if (raise[n]) for (here = n - 4; here <= n + 18 && here <= lines; here = here + 1) shown[here] = 1;
            if (comment[n] == "RTI") for (here = n; here <= n + 6; here = here + 1) shown[here] = 1;
        end
        planned = 1;
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
            20:      state_name = "PUSH_STATUS";
            21:      state_name = "PULL_STATUS";
            22:      state_name = "VECTOR";
            default: state_name = "?";
        endcase
    end

    integer cycle    = 0;       // cycles checked since the beginning
    integer patterns = 0;       // how many bytes the program has stored at $8000
    integer stored   = 0;       // the cycle of the last of them
    integer errors   = 0;
    integer nmis     = 0;       // how many times NMI went from 0 to 1
    reg     pressing = 0;
    reg [7:0] the_byte;

    // We look at the bus half-way between two ticks, when nothing moves. A
    // step is coming at the next tick: this is the end of a cycle.
    always @(negedge clk) begin
        if (step & ~reset & planned & (cycle < lines)) begin
            cycle    = cycle + 1;
            the_byte = write ? data_out : data_in;
            if (shown[cycle]) begin
                $display("cycle %4d: %-12s %h %s %h   %0s", cycle, state_name, address,
                         write ? "write" : "read ", the_byte, comment[cycle]);
            end
            if (address !== expected_address[cycle] || write !== expected_write[cycle]
                                                    || the_byte !== expected_byte[cycle]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: cycle %0d is %h %s %h, expected %h %s %h", cycle,
                                           address, write ? "write" : "read ", the_byte,
                                           expected_address[cycle],
                                           expected_write[cycle] ? "write" : "read ",
                                           expected_byte[cycle]);
            end
            // S2: the processor sees NMI at the next tick, the end of this cycle.
            if (raise[cycle]) begin
                nmi  = 1;
                nmis = nmis + 1;
                $display("cycle %4d: NMI goes from 0 to 1 at the end of this cycle (%0s)", cycle,
                         comment[cycle]);
            end
            if (lower[cycle]) nmi = 0;
            if (press[cycle]) pressing = 1;
            // A byte is on its way to the LEDs.
            if (write && address == 16'h8000) begin
                patterns = patterns + 1;
                $display("pattern %2d: %b, at cycle %0d, %0d cycles after the one before", patterns,
                         data_out[5:0], cycle, cycle - stored);
                stored = cycle;
            end
            // The stack at its deepest: two NMIs, one inside the other.
            if (deepest[cycle]) begin
                $display("the stack at its deepest, S = %h: from $01FF down, it holds", dut.processor.s);
                for (n = 255; n > dut.processor.s; n = n - 1) begin
                    $display("  $01%h  %h", n[7:0], dut.the_ram.cells[16'h0100 + n]);
                end
            end
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
    // cycles it is waiting for never come, it gives up after 40,000 ticks.
    initial begin
        #400000;
        $display("FAIL: computer, still waiting after 40,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Keep the waveform small: up to the second pattern.
        wait (patterns == 2);
        $dumpoff;

        // S1, pressed in the middle of the handler: the reset. Held for
        // three ticks, then let go.
        wait (pressing);
        @(posedge clk);
        #1 reset = 1;
        $display("S1 pressed, then let go: the reset");
        repeat (3) @(posedge clk);
        #1 reset = 0;

        wait (planned && cycle == lines);
        @(negedge clk);
        if (nmis != 6) begin
            errors = errors + 1;
            $display("wrong: NMI went up %0d times, expected 6", nmis);
        end
        if (patterns != writes) begin
            errors = errors + 1;
            $display("wrong: %0d bytes stored at $8000, expected %0d", patterns, writes);
        end

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, from the reset, with six NMIs and S1",
                     cycle);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
