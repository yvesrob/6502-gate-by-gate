// Chapter 23 uses the cpu from chapter 15. This file is a copy of it, unchanged.
// Chapter 15: our processor can be interrupted. Two wires come in, IRQ and
// NMI. When a device asks on one of them, the processor finishes the
// instruction it is doing, and instead of the next one it pushes pc and P,
// the flags as one byte, and goes on at the address that a vector, at the top
// of the ROM, points to. RTI pulls P and pc back, and the program goes on
// where it was. BRK does the same from inside a program. The flag I makes
// the processor refuse IRQ: CLI clears it, SEI sets it. PHP and PLP push P
// and pull it back. And the processor no longer starts at $C000: it reads
// where to start in the vector at $FFFC, as a 6502 does, after a reset that
// takes the same seven cycles as an interrupt. One new mode, BREAK, and
// three new states.
//
// It has the same three parts as in chapter 10. The decoder finds out what an
// opcode asks for. The sequencer takes the instruction through its cycles,
// one state for each. The data path takes values to the ALU, and keeps what
// comes back.
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
    input  wire        reset,           // 1: wait; then start again, where the vector at $FFFC says
    input  wire        step,            // 1: do one cycle at the next tick
    input  wire        irq,             // 1: a device asks for attention; the flag I can refuse it
    input  wire        nmi,             // from 0 to 1: a device asks, and it cannot be refused
    output reg  [15:0] address  = 0,    // the address bus: which byte we want
    input  wire [7:0]  data_in,         // the data bus, coming in: the byte we asked for
    output reg  [7:0]  data_out = 0,    // the data bus, going out: a byte to store
    output reg         write    = 0     // 1: store data_out at address
);
    `include "alu_operations.vh"

    // The instructions we know, by name. NOP does nothing: it is the 6502's
    // own NOP, and what we make of an opcode that we do not know yet.
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
    localparam SBC = 16;            // A = A - a byte, and one more if the carry is 0
    localparam AND = 17;            // A = A AND a byte, bit by bit
    localparam ORA = 18;            // A = A OR a byte
    localparam EOR = 19;            // A = A XOR a byte
    localparam CMP = 20;            // compare A with a byte: only the flags change
    localparam CPX = 21;            // the same for X...
    localparam CPY = 22;            // ...and for Y
    localparam ASL = 23;            // shift left: A, or a byte in memory
    localparam LSR = 24;            // shift right
    localparam ROL = 25;            // rotate left, through the carry
    localparam ROR = 26;            // rotate right, through the carry
    localparam SEC = 27;            // set the carry
    localparam SED = 28;            // set the decimal flag: ADC and SBC count in decimal
    localparam CLD = 29;            // clear it
    localparam TAX = 30;            // copy A into X
    localparam TAY = 31;            // copy A into Y
    localparam TXA = 32;            // copy X into A
    localparam TYA = 33;            // copy Y into A
    localparam BIT = 34;            // N and V from bits 7 and 6 of a byte, Z from A AND the byte
    localparam CLV = 35;            // clear the overflow flag
    localparam BPL = 36;            // branch if N is 0: plus
    localparam BMI = 37;            // branch if N is 1: minus
    localparam BVC = 38;            // branch if V is 0
    localparam BVS = 39;            // branch if V is 1
    localparam BCC = 40;            // branch if C is 0
    localparam BCS = 41;            // branch if C is 1
    localparam BNE = 42;            // branch if Z is 0: not equal
    localparam BEQ = 43;            // branch if Z is 1: equal
    localparam PHA = 44;            // push A onto the stack
    localparam PLA = 45;            // pull A back from the stack
    localparam JSR = 46;            // call a subroutine: push the address of its last byte, and jump
    localparam RTS = 47;            // return from it: pull that address, and go on after the JSR
    localparam TSX = 48;            // copy S into X
    localparam TXS = 49;            // copy X into S
    localparam PHP = 50;            // push P, the flags as one byte
    localparam PLP = 51;            // pull P back from the stack
    localparam BRK = 52;            // break: push pc and P, and go on where the vector at $FFFE says
    localparam RTI = 53;            // return from an interrupt: pull P and pc
    localparam CLI = 54;            // clear I: accept IRQ
    localparam SEI = 55;            // set I: refuse IRQ

    // Not opcodes: what the processor does instead of the next opcode when an
    // interrupt asks, and after a reset. Each one is a BRK that nobody wrote.
    localparam IRQ   = 56;
    localparam NMI   = 57;
    localparam RESET = 58;

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
    localparam ACCUMULATOR = 11;    // the shifts: nothing follows, the byte is A
    localparam RELATIVE    = 12;    // the branches: one byte follows, how far to go
    localparam STACK       = 13;    // PHA, PLA, PHP, PLP, RTS, RTI: nothing follows, they work on the stack
    localparam SUBROUTINE  = 14;    // JSR: an address follows, in two bytes, as for JMP
    localparam BREAK       = 15;    // BRK, the interrupts, the reset: pc and P go onto the stack,
                                    // and a vector says where to go on

    // The states: what is happening on the bus during the cycle that is ending.
    localparam STARTING     = 0;    // just switched on, or reset: the first cycle of the reset
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
    localparam BRANCH       = 12;   // a branch is taken: the next opcode arrives, for nothing
    localparam BRANCH_FIX   = 13;   // a read for nothing, while the page of the branch is put right
    localparam PUSH         = 14;   // a byte is being pushed onto the stack: A, or the low byte of pc
    localparam STACK_WAIT   = 15;   // a read of the stack, for nothing
    localparam PULL         = 16;   // a byte is arriving from the stack: for A, or the low byte of pc
    localparam PUSH_HIGH    = 17;   // JSR, BRK, an interrupt: the high byte of pc is being pushed
    localparam PULL_HIGH    = 18;   // RTS, RTI: the high byte of pc is arriving from the stack
    localparam RETURN       = 19;   // RTS: the last byte of the JSR is read again, for nothing
    localparam PUSH_STATUS  = 20;   // P is being pushed onto the stack
    localparam PULL_STATUS  = 21;   // P is arriving from the stack
    localparam VECTOR       = 22;   // the low byte of a vector is arriving

    // The registers that a program knows about.
    reg [15:0] pc = 0;              // the program counter: the byte of the program we are reading
    reg [7:0]  a  = 0;              // the accumulator
    reg [7:0]  x  = 0;              // the two index registers
    reg [7:0]  y  = 0;
    reg [7:0]  s  = 0;              // the stack pointer: the next byte pushed goes to $0100 + S

    reg carry    = 0;               // six flags: C,
    reg zero     = 0;               // Z,
    reg interrupt_disable = 0;      // I: when it is 1, the processor refuses IRQ,
    reg decimal  = 0;               // D,
    reg overflow = 0;               // V
    reg negative = 0;               // and N

    // The registers that are our own bookkeeping.
    reg [4:0] state       = STARTING;
    reg [5:0] instruction = NOP;        // what the opcode asked for...
    reg [3:0] mode        = IMPLIED;    // ...and where its operand is
    reg [7:0] low         = 0;          // the low byte of an address, while we fetch the high one;
                                        // or how far a branch goes
    reg       crossed     = 0;          // adding the index went past the end of a page
    reg [7:0] value       = 0;          // a changed byte, waiting to be written

    // ------------------------------------------------------------------
    // The interrupts. IRQ asks for as long as its wire is 1, and the flag I
    // can make the processor refuse it. NMI asks once, when its wire goes
    // from 0 to 1, and nothing can refuse it. A 6502 looks at the two wires
    // at the end of every cycle. At each step ours writes down whether an
    // interrupt asks, from what it saw at the end of the cycle before, and
    // with I as it is. When the next opcode arrives, what was written down
    // during the last cycle of the instruction decides: an interrupt asks,
    // and that opcode must wait. As 64doc says, "the interrupt must occur
    // before the last cycle of the current instruction".
    // ------------------------------------------------------------------
    reg irq_seen   = 0;         // IRQ, as it was at the end of the cycle before
    reg nmi_before = 0;         // NMI, the same
    reg nmi_seen   = 0;         // NMI went from 0 to 1, and has not been served yet
    reg asking     = 0;         // an interrupt asks: it takes the place of the next opcode

    always @(posedge clk) begin
        if (step) begin
            irq_seen   <= irq;
            nmi_before <= nmi;
            if (nmi & ~nmi_before) begin
                nmi_seen <= 1;
            end else if ((state == OPCODE) & asking & nmi_seen) begin
                nmi_seen <= 0;      // it is being served now
            end
            if (mode == BREAK) begin
                // BRK, an interrupt or the reset is under way. It does not
                // look: the first instruction of a handler always runs.
                asking <= 0;
            end else if (state != BRANCH) begin
                // A taken branch looks on its second cycle, not on its third.
                asking <= nmi_seen | (irq_seen & ~interrupt_disable);
            end
        end
    end

    // ------------------------------------------------------------------
    // The decoder. At the step where an opcode arrives, we look it up, and
    // we keep what the table says: which instruction, and which addressing
    // mode. One line for each opcode.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (step & (state == OPCODE) & ~asking) begin
            (* rom_style = "logic" *)   // for Yosys: build this table from logic, not in a block of memory
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
                // Copy a register into another.
                8'hAA:   begin instruction <= TAX; mode <= IMPLIED;     end
                8'hA8:   begin instruction <= TAY; mode <= IMPLIED;     end
                8'h8A:   begin instruction <= TXA; mode <= IMPLIED;     end
                8'h98:   begin instruction <= TYA; mode <= IMPLIED;     end
                8'hBA:   begin instruction <= TSX; mode <= IMPLIED;     end
                8'h9A:   begin instruction <= TXS; mode <= IMPLIED;     end
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
                // Add, subtract: A and a byte, and the carry.
                8'h69:   begin instruction <= ADC; mode <= IMMEDIATE;   end
                8'h65:   begin instruction <= ADC; mode <= ZERO_PAGE;   end
                8'h75:   begin instruction <= ADC; mode <= ZERO_PAGE_X; end
                8'h6D:   begin instruction <= ADC; mode <= ABSOLUTE;    end
                8'h7D:   begin instruction <= ADC; mode <= ABSOLUTE_X;  end
                8'h79:   begin instruction <= ADC; mode <= ABSOLUTE_Y;  end
                8'h61:   begin instruction <= ADC; mode <= INDIRECT_X;  end
                8'h71:   begin instruction <= ADC; mode <= INDIRECT_Y;  end
                8'hE9:   begin instruction <= SBC; mode <= IMMEDIATE;   end
                8'hE5:   begin instruction <= SBC; mode <= ZERO_PAGE;   end
                8'hF5:   begin instruction <= SBC; mode <= ZERO_PAGE_X; end
                8'hED:   begin instruction <= SBC; mode <= ABSOLUTE;    end
                8'hFD:   begin instruction <= SBC; mode <= ABSOLUTE_X;  end
                8'hF9:   begin instruction <= SBC; mode <= ABSOLUTE_Y;  end
                8'hE1:   begin instruction <= SBC; mode <= INDIRECT_X;  end
                8'hF1:   begin instruction <= SBC; mode <= INDIRECT_Y;  end
                // Compare a register with a byte.
                8'hC9:   begin instruction <= CMP; mode <= IMMEDIATE;   end
                8'hC5:   begin instruction <= CMP; mode <= ZERO_PAGE;   end
                8'hD5:   begin instruction <= CMP; mode <= ZERO_PAGE_X; end
                8'hCD:   begin instruction <= CMP; mode <= ABSOLUTE;    end
                8'hDD:   begin instruction <= CMP; mode <= ABSOLUTE_X;  end
                8'hD9:   begin instruction <= CMP; mode <= ABSOLUTE_Y;  end
                8'hC1:   begin instruction <= CMP; mode <= INDIRECT_X;  end
                8'hD1:   begin instruction <= CMP; mode <= INDIRECT_Y;  end
                8'hE0:   begin instruction <= CPX; mode <= IMMEDIATE;   end
                8'hE4:   begin instruction <= CPX; mode <= ZERO_PAGE;   end
                8'hEC:   begin instruction <= CPX; mode <= ABSOLUTE;    end
                8'hC0:   begin instruction <= CPY; mode <= IMMEDIATE;   end
                8'hC4:   begin instruction <= CPY; mode <= ZERO_PAGE;   end
                8'hCC:   begin instruction <= CPY; mode <= ABSOLUTE;    end
                // Combine A with a byte, bit by bit.
                8'h29:   begin instruction <= AND; mode <= IMMEDIATE;   end
                8'h25:   begin instruction <= AND; mode <= ZERO_PAGE;   end
                8'h35:   begin instruction <= AND; mode <= ZERO_PAGE_X; end
                8'h2D:   begin instruction <= AND; mode <= ABSOLUTE;    end
                8'h3D:   begin instruction <= AND; mode <= ABSOLUTE_X;  end
                8'h39:   begin instruction <= AND; mode <= ABSOLUTE_Y;  end
                8'h21:   begin instruction <= AND; mode <= INDIRECT_X;  end
                8'h31:   begin instruction <= AND; mode <= INDIRECT_Y;  end
                8'h09:   begin instruction <= ORA; mode <= IMMEDIATE;   end
                8'h05:   begin instruction <= ORA; mode <= ZERO_PAGE;   end
                8'h15:   begin instruction <= ORA; mode <= ZERO_PAGE_X; end
                8'h0D:   begin instruction <= ORA; mode <= ABSOLUTE;    end
                8'h1D:   begin instruction <= ORA; mode <= ABSOLUTE_X;  end
                8'h19:   begin instruction <= ORA; mode <= ABSOLUTE_Y;  end
                8'h01:   begin instruction <= ORA; mode <= INDIRECT_X;  end
                8'h11:   begin instruction <= ORA; mode <= INDIRECT_Y;  end
                8'h49:   begin instruction <= EOR; mode <= IMMEDIATE;   end
                8'h45:   begin instruction <= EOR; mode <= ZERO_PAGE;   end
                8'h55:   begin instruction <= EOR; mode <= ZERO_PAGE_X; end
                8'h4D:   begin instruction <= EOR; mode <= ABSOLUTE;    end
                8'h5D:   begin instruction <= EOR; mode <= ABSOLUTE_X;  end
                8'h59:   begin instruction <= EOR; mode <= ABSOLUTE_Y;  end
                8'h41:   begin instruction <= EOR; mode <= INDIRECT_X;  end
                8'h51:   begin instruction <= EOR; mode <= INDIRECT_Y;  end
                // Test the bits of a byte.
                8'h24:   begin instruction <= BIT; mode <= ZERO_PAGE;   end
                8'h2C:   begin instruction <= BIT; mode <= ABSOLUTE;    end
                // Shift, rotate: A, or a byte in memory.
                8'h0A:   begin instruction <= ASL; mode <= ACCUMULATOR; end
                8'h06:   begin instruction <= ASL; mode <= ZERO_PAGE;   end
                8'h16:   begin instruction <= ASL; mode <= ZERO_PAGE_X; end
                8'h0E:   begin instruction <= ASL; mode <= ABSOLUTE;    end
                8'h1E:   begin instruction <= ASL; mode <= ABSOLUTE_X;  end
                8'h4A:   begin instruction <= LSR; mode <= ACCUMULATOR; end
                8'h46:   begin instruction <= LSR; mode <= ZERO_PAGE;   end
                8'h56:   begin instruction <= LSR; mode <= ZERO_PAGE_X; end
                8'h4E:   begin instruction <= LSR; mode <= ABSOLUTE;    end
                8'h5E:   begin instruction <= LSR; mode <= ABSOLUTE_X;  end
                8'h2A:   begin instruction <= ROL; mode <= ACCUMULATOR; end
                8'h26:   begin instruction <= ROL; mode <= ZERO_PAGE;   end
                8'h36:   begin instruction <= ROL; mode <= ZERO_PAGE_X; end
                8'h2E:   begin instruction <= ROL; mode <= ABSOLUTE;    end
                8'h3E:   begin instruction <= ROL; mode <= ABSOLUTE_X;  end
                8'h6A:   begin instruction <= ROR; mode <= ACCUMULATOR; end
                8'h66:   begin instruction <= ROR; mode <= ZERO_PAGE;   end
                8'h76:   begin instruction <= ROR; mode <= ZERO_PAGE_X; end
                8'h6E:   begin instruction <= ROR; mode <= ABSOLUTE;    end
                8'h7E:   begin instruction <= ROR; mode <= ABSOLUTE_X;  end
                // The flags: the carry, the decimal flag, the overflow flag, and I.
                8'h18:   begin instruction <= CLC; mode <= IMPLIED;     end
                8'h38:   begin instruction <= SEC; mode <= IMPLIED;     end
                8'hD8:   begin instruction <= CLD; mode <= IMPLIED;     end
                8'hF8:   begin instruction <= SED; mode <= IMPLIED;     end
                8'hB8:   begin instruction <= CLV; mode <= IMPLIED;     end
                8'h58:   begin instruction <= CLI; mode <= IMPLIED;     end
                8'h78:   begin instruction <= SEI; mode <= IMPLIED;     end
                // Branch: go on somewhere else, if a flag says so.
                8'h10:   begin instruction <= BPL; mode <= RELATIVE;    end
                8'h30:   begin instruction <= BMI; mode <= RELATIVE;    end
                8'h50:   begin instruction <= BVC; mode <= RELATIVE;    end
                8'h70:   begin instruction <= BVS; mode <= RELATIVE;    end
                8'h90:   begin instruction <= BCC; mode <= RELATIVE;    end
                8'hB0:   begin instruction <= BCS; mode <= RELATIVE;    end
                8'hD0:   begin instruction <= BNE; mode <= RELATIVE;    end
                8'hF0:   begin instruction <= BEQ; mode <= RELATIVE;    end
                // Do nothing.
                8'hEA:   begin instruction <= NOP; mode <= IMPLIED;     end
                // Push A onto the stack, and pull it back. The same for P.
                8'h48:   begin instruction <= PHA; mode <= STACK;       end
                8'h68:   begin instruction <= PLA; mode <= STACK;       end
                8'h08:   begin instruction <= PHP; mode <= STACK;       end
                8'h28:   begin instruction <= PLP; mode <= STACK;       end
                // The two jumps.
                8'h4C:   begin instruction <= JMP; mode <= ABSOLUTE;    end
                8'h6C:   begin instruction <= JMP; mode <= INDIRECT;    end
                // Call a subroutine, and come back from it.
                8'h20:   begin instruction <= JSR; mode <= SUBROUTINE;  end
                8'h60:   begin instruction <= RTS; mode <= STACK;       end
                // Break, as an interrupt does. And come back from an interrupt.
                8'h00:   begin instruction <= BRK; mode <= BREAK;       end
                8'h40:   begin instruction <= RTI; mode <= STACK;       end
                default: begin instruction <= NOP; mode <= IMPLIED;     end
            endcase
        end
        // When an interrupt asks, it takes the place of the opcode that has
        // just arrived: it is a BRK that nobody wrote. NMI goes first.
        if (step & (state == OPCODE) & asking) begin
            instruction <= nmi_seen ? NMI : IRQ;
            mode        <= BREAK;
        end
        // The reset is one too, with a vector of its own.
        if (step & (state == STARTING)) begin
            instruction <= RESET;
            mode        <= BREAK;
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

    // The instructions that read a byte, change it, and write it back. (The
    // shifts do that when they have an address; on A they do not need one.)
    wire modifying;
    assign modifying = (instruction == INC) | (instruction == DEC)
                     | (instruction == ASL) | (instruction == LSR)
                     | (instruction == ROL) | (instruction == ROR);

    // Once the address of the byte is on the bus, the next state.
    wire [4:0] after_address;
    assign after_address = storing   ? STORE  :
                           modifying ? MODIFY : DATA;

    // The index: Y for the modes that say so, X for all the others.
    wire [7:0] index;
    assign index = ((mode == ZERO_PAGE_Y) | (mode == ABSOLUTE_Y) | (mode == INDIRECT_Y)) ? y : x;

    // A branch is taken when its flag says so. Each branch looks at one flag.
    wire taken;
    assign taken = (instruction == BPL) ? ~negative :
                   (instruction == BMI) ?  negative :
                   (instruction == BVC) ? ~overflow :
                   (instruction == BVS) ?  overflow :
                   (instruction == BCC) ? ~carry    :
                   (instruction == BCS) ?  carry    :
                   (instruction == BNE) ? ~zero     :
                   (instruction == BEQ) ?  zero     : 1'b0;

    // Where a taken branch goes: pc, which by then holds the address of the
    // next instruction, plus how far to go. That byte is signed, from -128 to
    // 127. Bit 7 repeated eight times makes it sixteen bits: $FA, which is -6,
    // becomes $FFFA, and adding $FFFA to an address takes 6 away from it.
    wire [15:0] target;
    assign target = pc + {{8{low[7]}}, low};

    // P: the six flags as one byte, the way PHP, BRK and the interrupts push
    // it. Bit 5 is always 1. Bit 4, B, is not a flag: it is 1 when an
    // instruction pushes P, and 0 when an interrupt does. That is how a
    // program can tell a BRK from an IRQ, which use the same vector.
    wire [7:0] status;
    assign status = {negative, overflow, 1'b1, (instruction == PHP) | (instruction == BRK),
                     decimal, interrupt_disable, zero, carry};

    // Where the program goes on after BRK or an interrupt. BRK skips the
    // byte that follows its opcode, and pc is on that byte. An interrupt
    // comes back to the opcode that had to wait, and pc is still on it.
    wire [15:0] return_address;
    assign return_address = (instruction == BRK) ? pc + 16'd1 : pc;

    // The three vectors, in the last six bytes of the ROM: where to go on.
    wire [15:0] vector;
    assign vector = (instruction == NMI)   ? 16'hFFFA :
                    (instruction == RESET) ? 16'hFFFC : 16'hFFFE;  // IRQ and BRK

    // ------------------------------------------------------------------
    // The sequencer. One step, one cycle. In each state it looks at the byte
    // that has just arrived, and it sets the bus for the next cycle.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            // Wait, reading at pc and writing nothing. When reset goes back
            // to 0, the reset begins.
            write   <= 0;
            address <= pc;
            state   <= STARTING;
        end else if (step) begin
            case (state)
                STARTING: begin
                    // The first of the seven cycles of the reset has read at
                    // pc, for nothing. It goes on as an interrupt does.
                    address <= pc;
                    state   <= OPERAND;
                end

                OPCODE: begin
                    if (asking) begin
                        // An interrupt: the opcode that has just arrived must
                        // wait. Read it again, for nothing. pc stays on it.
                        address <= pc;
                    end else begin
                        // Every instruction reads the byte that follows its opcode.
                        address <= pc + 16'd1;
                        pc      <= pc + 16'd1;
                    end
                    state <= OPERAND;
                end

                OPERAND: begin
                    case (mode)
                        IMPLIED, ACCUMULATOR: begin
                            // The instruction works on registers only: it is
                            // done. The byte that has just arrived was not
                            // for it: it is the next opcode. Ask for it again.
                            address <= pc;
                            state   <= OPCODE;
                            // S belongs to the sequencer, which uses it to make
                            // the addresses of the stack: TXS is done here.
                            if (instruction == TXS) begin
                                s <= x;
                            end
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
                        RELATIVE: begin
                            // A branch. The byte that has just arrived says
                            // how far to go: keep it, and ask for the next
                            // opcode. If the branch is not taken, that is
                            // all, as for an immediate value.
                            low     <= data_in;
                            address <= pc + 16'd1;
                            pc      <= pc + 16'd1;
                            state   <= taken ? BRANCH : OPCODE;
                        end
                        STACK: begin
                            // PHA, PHP, PLA, PLP, RTS, RTI. The byte that has
                            // just arrived is not theirs: they work on the stack,
                            // at $0100 + S. PHA pushes A there at once, PHP pushes
                            // P, and S moves down by one. The others first read
                            // there, for nothing.
                            address <= {8'h01, s};
                            if (instruction == PHA) begin
                                data_out <= a;
                                write    <= 1;
                                s        <= s - 8'd1;
                                state    <= PUSH;
                            end else if (instruction == PHP) begin
                                data_out <= status;
                                write    <= 1;
                                s        <= s - 8'd1;
                                state    <= PUSH_STATUS;
                            end else begin
                                state    <= STACK_WAIT;
                            end
                        end
                        SUBROUTINE: begin
                            // JSR. The low byte of the address has arrived:
                            // keep it. pc moves on to the high byte, the last
                            // byte of the JSR, but JSR does not fetch it yet:
                            // first it reads the stack, for nothing.
                            low     <= data_in;
                            pc      <= pc + 16'd1;
                            address <= {8'h01, s};
                            state   <= STACK_WAIT;
                        end
                        BREAK: begin
                            // BRK, an interrupt, or the reset. pc goes onto the
                            // stack, the high byte first, then P, and a vector
                            // says where to go on. The reset takes the same
                            // cycles, but it writes nothing: it reads the stack.
                            pc       <= return_address;
                            address  <= {8'h01, s};
                            data_out <= return_address[15:8];
                            write    <= (instruction != RESET);
                            s        <= s - 8'd1;
                            state    <= PUSH_HIGH;
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
                    end else if ((instruction == JMP) | (instruction == JSR) | (mode == BREAK)) begin
                        // That is where the program goes on. For BRK, an
                        // interrupt or the reset, the address in the vector.
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

                BRANCH: begin
                    // The branch is taken: the opcode that has just arrived
                    // is not the next one, it was read for nothing. The
                    // program goes on at the target.
                    pc <= target;
                    if (target[15:8] == pc[15:8]) begin
                        // On the same page: ask for the opcode there.
                        address <= target;
                        state   <= OPCODE;
                    end else begin
                        // On another page. A 6502 adds to the low byte of
                        // pc first, and reads there, on the old page, for
                        // nothing, while it puts the high byte right.
                        address <= {pc[15:8], target[7:0]};
                        state   <= BRANCH_FIX;
                    end
                end

                BRANCH_FIX: begin
                    // The page is right now: ask for the opcode at the target.
                    address <= pc;
                    state   <= OPCODE;
                end

                PUSH: begin
                    if (mode == BREAK) begin
                        // BRK, an interrupt: P goes onto the stack too, one
                        // place further down. The reset only reads there.
                        address  <= {8'h01, s};
                        data_out <= status;
                        s        <= s - 8'd1;
                        state    <= PUSH_STATUS;
                    end else begin
                        // The byte is on its way into the stack. pc says what
                        // comes next: for PHA the next opcode, for JSR the high
                        // byte of its address.
                        write   <= 0;
                        address <= pc;
                        state   <= (instruction == JSR) ? HIGH : OPCODE;
                    end
                end

                STACK_WAIT: begin
                    if (instruction == JSR) begin
                        // JSR pushes pc, the address of its own last byte:
                        // the high byte first, at $0100 + S, and S moves down.
                        address  <= {8'h01, s};
                        data_out <= pc[15:8];
                        write    <= 1;
                        s        <= s - 8'd1;
                        state    <= PUSH_HIGH;
                    end else begin
                        // PLA, PLP, RTS, RTI: S moves up by one, to the last
                        // byte pushed. Read it. For PLP and RTI, it is P.
                        s       <= s + 8'd1;
                        address <= {8'h01, s + 8'd1};
                        state   <= ((instruction == PLP) | (instruction == RTI)) ? PULL_STATUS : PULL;
                    end
                end

                PUSH_HIGH: begin
                    // Then the low byte, one place further down.
                    address  <= {8'h01, s};
                    data_out <= pc[7:0];
                    s        <= s - 8'd1;
                    state    <= PUSH;
                end

                PULL: begin
                    if ((instruction == RTS) | (instruction == RTI)) begin
                        // The low byte of the address that JSR, BRK or an
                        // interrupt pushed has arrived. Keep it, and pull the
                        // high byte, one place further up.
                        low     <= data_in;
                        s       <= s + 8'd1;
                        address <= {8'h01, s + 8'd1};
                        state   <= PULL_HIGH;
                    end else begin
                        // PLA: the data path takes the byte at this step.
                        // The next opcode is at pc.
                        address <= pc;
                        state   <= OPCODE;
                    end
                end

                PULL_HIGH: begin
                    // The address is complete. For RTI, that is where the
                    // program goes on. For RTS, it is the one JSR pushed, that
                    // of its own last byte: read there again, for nothing.
                    address <= {data_in, low};
                    pc      <= {data_in, low};
                    state   <= (instruction == RTI) ? OPCODE : RETURN;
                end

                RETURN: begin
                    // One byte further on is the instruction after the JSR.
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                    state   <= OPCODE;
                end

                PUSH_STATUS: begin
                    // P is on its way into the stack.
                    write <= 0;
                    if (mode == BREAK) begin
                        // BRK, an interrupt, the reset: read the low byte of
                        // the vector.
                        address <= vector;
                        state   <= VECTOR;
                    end else begin
                        // PHP: the next opcode is at pc.
                        address <= pc;
                        state   <= OPCODE;
                    end
                end

                PULL_STATUS: begin
                    // P has arrived: the data path takes it at this step.
                    if (instruction == RTI) begin
                        // RTI: then the low byte of pc, one place further up.
                        s       <= s + 8'd1;
                        address <= {8'h01, s + 8'd1};
                        state   <= PULL;
                    end else begin
                        // PLP: the next opcode is at pc.
                        address <= pc;
                        state   <= OPCODE;
                    end
                end

                VECTOR: begin
                    // The low byte of the vector has arrived. Keep it, and
                    // fetch the high byte, at the next address.
                    low     <= data_in;
                    address <= address + 16'd1;
                    state   <= HIGH;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // The data path: the ALU, what each instruction asks of it, where its
    // result goes, and which flags change.
    // ------------------------------------------------------------------
    wire [3:0] operation;
    assign operation = (instruction == ADC)                         ? ALU_ADD          :
                       (instruction == SBC)                         ? ALU_SUBTRACT     :
                       ((instruction == CMP) | (instruction == CPX)
                                             | (instruction == CPY)) ? ALU_COMPARE      :
                       ((instruction == AND) | (instruction == BIT)) ? ALU_AND          :
                       (instruction == ORA)                         ? ALU_OR           :
                       (instruction == EOR)                         ? ALU_XOR          :
                       (instruction == ASL)                         ? ALU_SHIFT_LEFT   :
                       (instruction == ROL)                         ? ALU_ROTATE_LEFT  :
                       (instruction == LSR)                         ? ALU_SHIFT_RIGHT  :
                       (instruction == ROR)                         ? ALU_ROTATE_RIGHT :
                       ((instruction == INX) | (instruction == INY)
                                             | (instruction == INC)) ? ALU_INCREMENT    :
                       ((instruction == DEX) | (instruction == DEY)
                                             | (instruction == DEC)) ? ALU_DECREMENT    : ALU_PASS;

    // The value the ALU works on: the byte from memory, or a register. A
    // byte that is being changed in memory comes from memory too, and so
    // does a byte pulled from the stack.
    wire [7:0] alu_a;
    assign alu_a = ((instruction == LDA) | (instruction == LDX) | (instruction == LDY)
                  | (instruction == PLA) | (state == MODIFY))                  ? data_in :
                   ((instruction == INX) | (instruction == DEX) | (instruction == CPX)
                  | (instruction == TXA))                                      ? x :
                   ((instruction == INY) | (instruction == DEY) | (instruction == CPY)
                  | (instruction == TYA))                                      ? y :
                   (instruction == TSX)                                        ? s : a;

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
        .decimal   (decimal),
        .result    (result),
        .carry_out (result_carry),
        .overflow  (result_overflow),
        .negative  (result_negative),
        .zero      (result_zero)
    );

    // An instruction does its work at the step where its operand is there:
    // right after the opcode, when the byte comes from its address, or when
    // it comes from the stack.
    wire working;
    assign working = ((state == OPERAND) & ((mode == IMPLIED) | (mode == ACCUMULATOR)
                                                              | (mode == IMMEDIATE)))
                   | (state == DATA) | (state == MODIFY) | (state == PULL);

    always @(posedge clk) begin
        if (step & ~reset & working) begin
            case (instruction)
                LDA, AND, ORA, EOR, TXA, TYA, PLA: begin
                    a        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                LDX, INX, DEX, TAX, TSX: begin
                    x        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                LDY, INY, DEY, TAY: begin
                    y        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                INC, DEC: begin
                    value    <= result;     // the sequencer writes it two cycles later
                    negative <= result_negative;
                    zero     <= result_zero;
                end
                ADC, SBC: begin
                    a        <= result;
                    negative <= result_negative;
                    zero     <= result_zero;
                    carry    <= result_carry;
                    overflow <= result_overflow;
                end
                CMP, CPX, CPY: begin
                    // Only the flags: the difference itself is not kept.
                    negative <= result_negative;
                    zero     <= result_zero;
                    carry    <= result_carry;
                end
                ASL, LSR, ROL, ROR: begin
                    if (mode == ACCUMULATOR) begin
                        a     <= result;
                    end else begin
                        value <= result;    // the sequencer writes it two cycles later
                    end
                    negative <= result_negative;
                    zero     <= result_zero;
                    carry    <= result_carry;
                end
                BIT: begin
                    // N and V are bits 7 and 6 of the byte itself. Only Z
                    // looks at A: it says whether A AND the byte is zero.
                    negative <= data_in[7];
                    overflow <= data_in[6];
                    zero     <= result_zero;
                end
                CLC: begin
                    carry <= 0;
                end
                SEC: begin
                    carry <= 1;
                end
                CLD: begin
                    decimal <= 0;
                end
                SED: begin
                    decimal <= 1;
                end
                CLV: begin
                    overflow <= 0;
                end
                CLI: begin
                    interrupt_disable <= 0;
                end
                SEI: begin
                    interrupt_disable <= 1;
                end
            endcase
        end
        // PLP and RTI: the six flags come back from the stack, all at once.
        // Bits 5 and 4 of the byte are not flags: they go nowhere.
        if (step & ~reset & (state == PULL_STATUS)) begin
            negative          <= data_in[7];
            overflow          <= data_in[6];
            decimal           <= data_in[3];
            interrupt_disable <= data_in[2];
            zero              <= data_in[1];
            carry             <= data_in[0];
        end
        // BRK, the interrupts and the reset set I, so that IRQ cannot
        // interrupt what the vector points to. For BRK and the interrupts,
        // P is on the stack already, with I as it was.
        if (step & ~reset & (state == VECTOR)) begin
            interrupt_disable <= 1;
        end
    end
endmodule
