// Chapter 10: our processor runs its first instructions: LDA, STA, CLC, ADC
// and JMP. It has three parts. The decoder finds out what an opcode asks for.
// The sequencer takes the instruction through its cycles, one state for each.
// The data path takes values to the ALU, and keeps what comes back.
//
// The processor is a state machine, like the scanner from chapter 3: it runs on
// the fast clock and moves only when step is 1. One step is one cycle of the
// 6502: one byte read from memory, or one byte written to it.
//
// The bus. At a step, the processor sets address and, to write, data_out and
// write. At the next tick the memory takes them, and a byte we asked for is
// on data_in after that tick. So a cycle needs two ticks at least: step must
// never be 1 two ticks in a row.
module cpu (
    input  wire        clk,
    input  wire        reset,           // 1: start again from the first instruction
    input  wire        step,            // 1: do one cycle at the next tick
    output reg  [15:0] address  = 0,    // the address bus: which byte we want
    input  wire [7:0]  data_in,         // the data bus, coming in: the byte we asked for
    output reg  [7:0]  data_out = 0,    // the data bus, going out: a byte to store
    output reg         write    = 0     // 1: store data_out at address
);
    `include "alu_operations.vh"

    // Where the program begins: the first byte of the ROM. A real 6502 looks
    // this address up in memory. Ours will too, in chapter 15.
    parameter START = 16'hC000;

    // The instructions we know, by name. NOP does nothing: it is what we make
    // of an opcode that we do not know yet.
    localparam NOP = 0;
    localparam LDA = 1;
    localparam STA = 2;
    localparam CLC = 3;
    localparam ADC = 4;
    localparam JMP = 5;

    // The addressing modes: where an instruction finds what it works on.
    localparam IMPLIED   = 0;       // nothing follows the opcode
    localparam IMMEDIATE = 1;       // the value itself follows
    localparam ABSOLUTE  = 2;       // an address follows, in two bytes

    // The states: what is happening on the bus during the cycle that is ending.
    localparam STARTING = 0;        // just switched on, or reset
    localparam OPCODE   = 1;        // an opcode is arriving
    localparam OPERAND  = 2;        // the byte that follows the opcode is arriving
    localparam HIGH     = 3;        // the high byte of an address is arriving
    localparam STORE    = 4;        // a byte is being written

    // The registers that a program knows about.
    reg [15:0] pc = 0;              // the program counter: the byte of the program we are reading
    reg [7:0]  a  = 0;              // the accumulator

    reg carry    = 0;               // four flags: C,
    reg zero     = 0;               // Z,
    reg overflow = 0;               // V
    reg negative = 0;               // and N

    // The registers that are our own bookkeeping.
    reg [2:0] state       = STARTING;
    reg [2:0] instruction = NOP;        // what the opcode asked for...
    reg [1:0] mode        = IMPLIED;    // ...and where its operand is
    reg [7:0] low         = 0;          // the low byte of an address, while we fetch the high one

    // ------------------------------------------------------------------
    // The decoder. At the step where an opcode arrives, we look it up, and
    // we keep what the table says: which instruction, and which addressing
    // mode. One line for each opcode.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (step & (state == OPCODE)) begin
            case (data_in)
                8'h18:   begin instruction <= CLC; mode <= IMPLIED;   end
                8'h4C:   begin instruction <= JMP; mode <= ABSOLUTE;  end
                8'h69:   begin instruction <= ADC; mode <= IMMEDIATE; end
                8'h8D:   begin instruction <= STA; mode <= ABSOLUTE;  end
                8'hA9:   begin instruction <= LDA; mode <= IMMEDIATE; end
                default: begin instruction <= NOP; mode <= IMPLIED;   end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // The sequencer. One step, one cycle. In each state it looks at the byte
    // that has just arrived, and it sets the bus for the next cycle.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            write <= 0;
            state <= STARTING;
        end else if (step) begin
            case (state)
                STARTING: begin
                    // Ask for the first byte of the program.
                    address <= START;
                    pc      <= START;
                    state   <= OPCODE;
                end

                OPCODE: begin
                    // Every instruction reads the byte that follows its opcode.
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                    state   <= OPERAND;
                end

                OPERAND: begin
                    case (mode)
                        IMPLIED: begin
                            // The instruction works on registers only: it is
                            // done. The byte that has just arrived was not
                            // for it: it is the next opcode. Ask for it again.
                            address <= pc;
                            state   <= OPCODE;
                        end
                        IMMEDIATE: begin
                            // The value is the byte that has just arrived:
                            // done. The next opcode is the byte after it.
                            address <= pc + 16'd1;
                            pc      <= pc + 16'd1;
                            state   <= OPCODE;
                        end
                        ABSOLUTE: begin
                            // The low byte of an address has arrived. Keep
                            // it, and ask for the high byte.
                            low     <= data_in;
                            address <= pc + 16'd1;
                            pc      <= pc + 16'd1;
                            state   <= HIGH;
                        end
                    endcase
                end

                HIGH: begin
                    // The address is complete: the byte that has just arrived,
                    // and the one we kept.
                    address <= {data_in, low};
                    if (instruction == JMP) begin
                        // That is where the program goes on.
                        pc    <= {data_in, low};
                        state <= OPCODE;
                    end else begin
                        // STA: that is where A must be written.
                        data_out <= a;
                        write    <= 1;
                        state    <= STORE;
                    end
                end

                STORE: begin
                    // The byte is on its way into the memory. Back to the
                    // program: pc still knows where we were.
                    write   <= 0;
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // The data path: the ALU, what each instruction asks of it, where its
    // result goes, and which flags change.
    // ------------------------------------------------------------------
    wire [3:0] operation;
    assign operation = (instruction == ADC) ? ALU_ADD : ALU_PASS;

    // The value the ALU works on: the byte from memory, or the accumulator.
    wire [7:0] alu_a;
    assign alu_a = (instruction == LDA) ? data_in : a;

    wire [7:0] result;
    wire       result_carry;
    wire       result_overflow;
    wire       result_negative;
    wire       result_zero;

    alu the_alu (
        .operation (operation),
        .a         (alu_a),
        .b         (data_in),
        .carry_in  (carry),
        .result    (result),
        .carry_out (result_carry),
        .overflow  (result_overflow),
        .negative  (result_negative),
        .zero      (result_zero)
    );

    // An instruction does its work at the step where its operand is there.
    wire working;
    assign working = (state == OPERAND) & ((mode == IMPLIED) | (mode == IMMEDIATE));

    always @(posedge clk) begin
        if (step & ~reset & working) begin
            case (instruction)
                LDA: begin
                    a        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                ADC: begin
                    a        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                    carry    <= result_carry;
                    overflow <= result_overflow;
                end
                CLC: begin
                    carry <= 0;
                end
            endcase
        end
    end
endmodule
