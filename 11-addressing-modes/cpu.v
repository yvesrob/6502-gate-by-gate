// Chapter 11: our processor gets its two index registers, X and Y, and the
// other ways of saying where a byte is: page zero, an index added to an
// address, an address kept in memory. It can now read a byte at an address,
// and change a byte of memory where it is. It has the same three parts as in
// chapter 10. The decoder finds out what an opcode asks for. The sequencer
// takes the instruction through its cycles, one state for each. The data path
// takes values to the ALU, and keeps what comes back.
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
    localparam LDX = 6;             // LDA and STA, for X...
    localparam STX = 7;
    localparam LDY = 8;             // ...and for Y
    localparam STY = 9;
    localparam INX = 10;            // X = X + 1
    localparam DEX = 11;            // X = X - 1
    localparam INY = 12;            // the same for Y
    localparam DEY = 13;
    localparam INC = 14;            // a byte in memory, plus one
    localparam DEC = 15;            // a byte in memory, minus one

    // The addressing modes: where an instruction finds what it works on.
    localparam IMPLIED     = 0;     // nothing follows the opcode
    localparam IMMEDIATE   = 1;     // the value itself follows
    localparam ABSOLUTE    = 2;     // an address follows, in two bytes
    localparam ZERO_PAGE   = 3;     // one byte follows: an address in page zero
    localparam ZERO_PAGE_X = 4;     // the same, plus X
    localparam ZERO_PAGE_Y = 5;     // the same, plus Y
    localparam ABSOLUTE_X  = 6;     // two bytes follow: an address, plus X
    localparam ABSOLUTE_Y  = 7;     // the same, plus Y
    localparam INDIRECT_X  = 8;     // (zp,X): the address is kept in page zero, at zp + X
    localparam INDIRECT_Y  = 9;     // (zp),Y: the address is kept in page zero, at zp; plus Y
    localparam INDIRECT    = 10;    // JMP (address): the target is kept in memory, there

    // The states: what is happening on the bus during the cycle that is ending.
    localparam STARTING     = 0;    // just switched on, or reset
    localparam OPCODE       = 1;    // an opcode is arriving
    localparam OPERAND      = 2;    // the byte that follows the opcode is arriving
    localparam HIGH         = 3;    // the high byte of an address is arriving
    localparam STORE        = 4;    // a byte is being written
    localparam DATA         = 5;    // the byte the instruction works on is arriving
    localparam INDEX        = 6;    // a read for nothing, while the index is added
    localparam FIX          = 7;    // a read for nothing, while the page is put right
    localparam POINTER_LOW  = 8;    // the low byte of an address kept in memory is arriving
    localparam POINTER_HIGH = 9;    // its high byte is arriving
    localparam MODIFY       = 10;   // the byte to change is arriving
    localparam WRITE_BACK   = 11;   // the byte is being written back, unchanged

    // The registers that a program knows about.
    reg [15:0] pc = 0;              // the program counter: the byte of the program we are reading
    reg [7:0]  a  = 0;              // the accumulator
    reg [7:0]  x  = 0;              // the two index registers
    reg [7:0]  y  = 0;

    reg carry    = 0;               // four flags: C,
    reg zero     = 0;               // Z,
    reg overflow = 0;               // V
    reg negative = 0;               // and N

    // The registers that are our own bookkeeping.
    reg [3:0] state       = STARTING;
    reg [3:0] instruction = NOP;        // what the opcode asked for...
    reg [3:0] mode        = IMPLIED;    // ...and where its operand is
    reg [7:0] low         = 0;          // the low byte of an address, while we fetch the high one
    reg       crossed     = 0;          // adding the index went past the end of a page
    reg [7:0] value       = 0;          // a changed byte, waiting to be written

    // ------------------------------------------------------------------
    // The decoder. At the step where an opcode arrives, we look it up, and
    // we keep what the table says: which instruction, and which addressing
    // mode. One line for each opcode.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (step & (state == OPCODE)) begin
            case (data_in)
                // Load a register.
                8'hA9:   begin instruction <= LDA; mode <= IMMEDIATE;   end
                8'hA5:   begin instruction <= LDA; mode <= ZERO_PAGE;   end
                8'hB5:   begin instruction <= LDA; mode <= ZERO_PAGE_X; end
                8'hAD:   begin instruction <= LDA; mode <= ABSOLUTE;    end
                8'hBD:   begin instruction <= LDA; mode <= ABSOLUTE_X;  end
                8'hB9:   begin instruction <= LDA; mode <= ABSOLUTE_Y;  end
                8'hA1:   begin instruction <= LDA; mode <= INDIRECT_X;  end
                8'hB1:   begin instruction <= LDA; mode <= INDIRECT_Y;  end
                8'hA2:   begin instruction <= LDX; mode <= IMMEDIATE;   end
                8'hA6:   begin instruction <= LDX; mode <= ZERO_PAGE;   end
                8'hB6:   begin instruction <= LDX; mode <= ZERO_PAGE_Y; end
                8'hAE:   begin instruction <= LDX; mode <= ABSOLUTE;    end
                8'hBE:   begin instruction <= LDX; mode <= ABSOLUTE_Y;  end
                8'hA0:   begin instruction <= LDY; mode <= IMMEDIATE;   end
                8'hA4:   begin instruction <= LDY; mode <= ZERO_PAGE;   end
                8'hB4:   begin instruction <= LDY; mode <= ZERO_PAGE_X; end
                8'hAC:   begin instruction <= LDY; mode <= ABSOLUTE;    end
                8'hBC:   begin instruction <= LDY; mode <= ABSOLUTE_X;  end
                // Store a register.
                8'h85:   begin instruction <= STA; mode <= ZERO_PAGE;   end
                8'h95:   begin instruction <= STA; mode <= ZERO_PAGE_X; end
                8'h8D:   begin instruction <= STA; mode <= ABSOLUTE;    end
                8'h9D:   begin instruction <= STA; mode <= ABSOLUTE_X;  end
                8'h99:   begin instruction <= STA; mode <= ABSOLUTE_Y;  end
                8'h81:   begin instruction <= STA; mode <= INDIRECT_X;  end
                8'h91:   begin instruction <= STA; mode <= INDIRECT_Y;  end
                8'h86:   begin instruction <= STX; mode <= ZERO_PAGE;   end
                8'h96:   begin instruction <= STX; mode <= ZERO_PAGE_Y; end
                8'h8E:   begin instruction <= STX; mode <= ABSOLUTE;    end
                8'h84:   begin instruction <= STY; mode <= ZERO_PAGE;   end
                8'h94:   begin instruction <= STY; mode <= ZERO_PAGE_X; end
                8'h8C:   begin instruction <= STY; mode <= ABSOLUTE;    end
                // Add one, take one away: to a register, or to a byte in memory.
                8'hE8:   begin instruction <= INX; mode <= IMPLIED;     end
                8'hCA:   begin instruction <= DEX; mode <= IMPLIED;     end
                8'hC8:   begin instruction <= INY; mode <= IMPLIED;     end
                8'h88:   begin instruction <= DEY; mode <= IMPLIED;     end
                8'hE6:   begin instruction <= INC; mode <= ZERO_PAGE;   end
                8'hF6:   begin instruction <= INC; mode <= ZERO_PAGE_X; end
                8'hEE:   begin instruction <= INC; mode <= ABSOLUTE;    end
                8'hFE:   begin instruction <= INC; mode <= ABSOLUTE_X;  end
                8'hC6:   begin instruction <= DEC; mode <= ZERO_PAGE;   end
                8'hD6:   begin instruction <= DEC; mode <= ZERO_PAGE_X; end
                8'hCE:   begin instruction <= DEC; mode <= ABSOLUTE;    end
                8'hDE:   begin instruction <= DEC; mode <= ABSOLUTE_X;  end
                // The addition from chapter 10, and the two jumps.
                8'h18:   begin instruction <= CLC; mode <= IMPLIED;     end
                8'h69:   begin instruction <= ADC; mode <= IMMEDIATE;   end
                8'h4C:   begin instruction <= JMP; mode <= ABSOLUTE;    end
                8'h6C:   begin instruction <= JMP; mode <= INDIRECT;    end
                default: begin instruction <= NOP; mode <= IMPLIED;     end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // What the instruction and its mode tell the sequencer.
    // ------------------------------------------------------------------

    // The instructions that write a register into memory, and the register.
    wire storing;
    assign storing = (instruction == STA) | (instruction == STX) | (instruction == STY);

    wire [7:0] stored;
    assign stored = (instruction == STX) ? x :
                    (instruction == STY) ? y : a;

    // The instructions that read a byte, change it, and write it back.
    wire modifying;
    assign modifying = (instruction == INC) | (instruction == DEC);

    // Once the address of the byte is on the bus, the next state.
    wire [3:0] after_address;
    assign after_address = storing   ? STORE  :
                           modifying ? MODIFY : DATA;

    // The index: Y for the modes that say so, X for all the others.
    wire [7:0] index;
    assign index = ((mode == ZERO_PAGE_Y) | (mode == ABSOLUTE_Y) | (mode == INDIRECT_Y)) ? y : x;

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
                        ABSOLUTE, INDIRECT: begin
                            // The low byte of an address has arrived. Keep
                            // it, and ask for the high byte.
                            low     <= data_in;
                            address <= pc + 16'd1;
                            pc      <= pc + 16'd1;
                            state   <= HIGH;
                        end
                        ABSOLUTE_X, ABSOLUTE_Y: begin
                            // The same, but the index is added to the low
                            // byte at once. If the sum needs a ninth bit, the
                            // address is on the next page: crossed keeps it.
                            {crossed, low} <= data_in + index;
                            address <= pc + 16'd1;
                            pc      <= pc + 16'd1;
                            state   <= HIGH;
                        end
                        ZERO_PAGE: begin
                            // The address is the byte that has just arrived,
                            // in page zero. Read there, or write there.
                            address  <= {8'h00, data_in};
                            data_out <= stored;
                            write    <= storing;
                            state    <= after_address;
                        end
                        ZERO_PAGE_X, ZERO_PAGE_Y, INDIRECT_X: begin
                            // Read there first, for nothing: the index is
                            // added during that cycle.
                            address <= {8'h00, data_in};
                            state   <= INDEX;
                        end
                        INDIRECT_Y: begin
                            // An address is kept in page zero, there. Fetch
                            // its low byte.
                            address <= {8'h00, data_in};
                            state   <= POINTER_LOW;
                        end
                    endcase
                end

                HIGH: begin
                    // The address is complete: the byte that has just arrived,
                    // and the one we kept.
                    address <= {data_in, low};
                    if (mode == INDIRECT) begin
                        // JMP (address): the target is kept there. Fetch it.
                        state <= POINTER_LOW;
                    end else if (instruction == JMP) begin
                        // That is where the program goes on.
                        pc    <= {data_in, low};
                        state <= OPCODE;
                    end else if (mode == ABSOLUTE) begin
                        // Read there, or write there.
                        data_out <= stored;
                        write    <= storing;
                        state    <= after_address;
                    end else if (crossed | storing | modifying) begin
                        // The index took us to the next page, and the high
                        // byte does not know it yet. Read here for nothing,
                        // and put the page right. A byte must never be
                        // written at a wrong address, so an instruction that
                        // writes always takes this cycle.
                        state <= FIX;
                    end else begin
                        // The index stayed on the page: the address is right.
                        state <= DATA;
                    end
                end

                INDEX: begin
                    // Add the index. Only the low byte of the address
                    // changes: page zero plus an index is still page zero.
                    address[7:0] <= address[7:0] + index;
                    if (mode == INDIRECT_X) begin
                        state <= POINTER_LOW;
                    end else begin
                        data_out <= stored;
                        write    <= storing;
                        state    <= after_address;
                    end
                end

                FIX: begin
                    // If the index went past the end of the page, the high
                    // byte of the address gets the carry now.
                    if (crossed) begin
                        address[15:8] <= address[15:8] + 8'd1;
                    end
                    data_out <= stored;
                    write    <= storing;
                    state    <= after_address;
                end

                POINTER_LOW: begin
                    // The low byte of an address kept in memory has arrived.
                    // Keep it (for (zp),Y, with Y added to it), and fetch the
                    // high byte from the next cell. Only the low byte of the
                    // address changes: the next cell is looked for on the same
                    // page, even when the page has no cell left.
                    if (mode == INDIRECT_Y) begin
                        {crossed, low} <= data_in + index;
                    end else begin
                        low <= data_in;
                    end
                    address[7:0] <= address[7:0] + 8'd1;
                    state        <= POINTER_HIGH;
                end

                POINTER_HIGH: begin
                    // The address that was kept in memory is complete.
                    address <= {data_in, low};
                    if (mode == INDIRECT) begin
                        // JMP (address): that is where the program goes on.
                        pc    <= {data_in, low};
                        state <= OPCODE;
                    end else if (mode == INDIRECT_X) begin
                        data_out <= stored;
                        write    <= storing;
                        state    <= after_address;
                    end else if (crossed | storing | modifying) begin
                        // (zp),Y: as for an absolute address plus an index.
                        state <= FIX;
                    end else begin
                        state <= DATA;
                    end
                end

                DATA: begin
                    // The byte the instruction works on has arrived, and the
                    // data path takes it at this step. Back to the program.
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end

                STORE: begin
                    // The byte is on its way into the memory. Back to the
                    // program: pc still knows where we were.
                    write   <= 0;
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end

                MODIFY: begin
                    // The byte to change has arrived, and the data path works
                    // out its new value at this step. A 6502 first writes the
                    // byte back as it was. The address stays where it is.
                    data_out <= data_in;
                    write    <= 1;
                    state    <= WRITE_BACK;
                end

                WRITE_BACK: begin
                    // Then it writes the new value, at the same address.
                    data_out <= value;
                    state    <= STORE;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // The data path: the ALU, what each instruction asks of it, where its
    // result goes, and which flags change.
    // ------------------------------------------------------------------
    wire [3:0] operation;
    assign operation = (instruction == ADC)                         ? ALU_ADD       :
                       ((instruction == INX) | (instruction == INY)
                                             | (instruction == INC)) ? ALU_INCREMENT :
                       ((instruction == DEX) | (instruction == DEY)
                                             | (instruction == DEC)) ? ALU_DECREMENT : ALU_PASS;

    // The value the ALU works on: the byte from memory, or a register.
    wire [7:0] alu_a;
    assign alu_a = ((instruction == LDA) | (instruction == LDX) | (instruction == LDY)
                  | (instruction == INC) | (instruction == DEC))  ? data_in :
                   ((instruction == INX) | (instruction == DEX))  ? x       :
                   ((instruction == INY) | (instruction == DEY))  ? y       : a;

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

    // An instruction does its work at the step where its operand is there:
    // right after the opcode, or when the byte comes from its address.
    wire working;
    assign working = ((state == OPERAND) & ((mode == IMPLIED) | (mode == IMMEDIATE)))
                   | (state == DATA) | (state == MODIFY);

    always @(posedge clk) begin
        if (step & ~reset & working) begin
            case (instruction)
                LDA: begin
                    a        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                LDX, INX, DEX: begin
                    x        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                LDY, INY, DEY: begin
                    y        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                INC, DEC: begin
                    value    <= result;     // the sequencer writes it two cycles later
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
