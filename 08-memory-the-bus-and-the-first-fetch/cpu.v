// Chapter 8: the first piece of our processor. It cannot do anything yet but
// fetch: it reads the bytes of the program one after the other, and takes
// each of them for an opcode.
//
// The processor is a state machine, like the scanner from chapter 3: it runs on
// the fast clock and moves only when step is 1. One step is one cycle of the
// 6502: one byte read from memory or, from chapter 10 on, one byte written.
//
// The bus. At a step, the processor sets address. At the next tick the memory
// takes it, and the byte is on data_in after that tick. So a cycle needs two
// ticks at least: step must never be 1 two ticks in a row.
module cpu (
    input  wire        clk,
    input  wire        reset,           // 1: start again from the first instruction
    input  wire        step,            // 1: do one cycle at the next tick
    output reg  [15:0] address  = 0,    // the address bus: which byte we want
    input  wire [7:0]  data_in,         // the data bus, coming in: the byte we asked for
    output reg  [7:0]  data_out = 0,    // the data bus, going out: a byte to store
    output reg         write    = 0     // 1: store data_out at address
);
    // Where the program begins: the first byte of the ROM. A real 6502 looks
    // this address up in memory. Ours will too, in chapter 15.
    parameter START = 16'hC000;

    // The two states of this first machine.
    localparam STARTING = 0;    // just switched on, or reset
    localparam OPCODE   = 1;    // an opcode is arriving

    reg        state  = STARTING;
    reg [15:0] pc     = 0;      // the program counter: the address of the byte we are reading
    reg [7:0]  opcode = 0;      // the byte we have just fetched

    always @(posedge clk) begin
        if (reset) begin
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
                    // The byte we asked for is there: keep it, and ask for
                    // the next one.
                    opcode  <= data_in;
                    address <= pc + 16'd1;
                    pc      <= pc + 16'd1;
                end
            endcase
        end
    end
endmodule
