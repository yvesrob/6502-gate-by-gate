// Chapter 16, test bench for the whole computer, with the program of the
// board, functional.s. It lets the computer run Klaus Dormann's functional
// test once, all the way through: about 96 million cycles, which take the
// simulator a quarter of an hour. Here the test is the judge, not the test
// bench: the test bench only watches. It says when the copy is done, when
// each part of the test begins (the test writes the number of each part at
// $0200), and how the test ends: at $3469, its success, or anywhere else,
// in one of its traps, the loops that jump to themselves.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         reset = 0;
    wire        step;
    wire [5:0]  leds;
    wire [15:0] address;
    wire [7:0]  data_in;
    wire [7:0]  data_out;
    wire        write;

    // The timer from chapter 3 says when the processor moves. 2 is as fast
    // as the bus allows, as on the board in this chapter.
    timer #(.PERIOD(2)) step_timer (
        .clk   (clk),
        .pulse (step)
    );

    computer dut (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .irq      (1'b0),       // nothing asks for an interrupt during the test
        .nmi      (1'b0),
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // In the chip the RAM starts at zero; in the simulator it starts unknown.
    // The test bench does what the chip does. It also reads the ROM, to check
    // the copy.
    reg [7:0] program [0:16383];
    integer   n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) begin
            dut.the_ram.cells[n] = 8'h00;
        end
        $readmemh("rom.hex", program);
    end

    localparam TEST    = 16'h0400;  // the first instruction of the test
    localparam SUCCESS = 16'h3469;  // where it ends when all went well
    localparam LIMIT   = 100_000_000;

    integer    cycle        = 0;
    integer    instructions = 0;
    integer    began        = 0;    // the cycle at which the test began, at $0400
    integer    reached      = 0;    // the cycle at which it reached $3469
    integer    errors       = 0;
    integer    different;
    reg [15:0] opcode_at    = 16'hFFFF;     // where the last instruction began
    reg [7:0]  part         = 8'h00;        // the number of the part of the test under way
    reg        stuck        = 0;
    integer    shown        = 0;    // the cycle at which the count went onto the LEDs

    // At the end of every cycle. An instruction begins when an opcode arrives
    // (state OPCODE, and no interrupt asking).
    always @(negedge clk) begin
        if (step & ~reset) begin
            cycle = cycle + 1;
            if (dut.processor.state == 1 && !dut.processor.asking) begin
                instructions = instructions + 1;
                if (address == opcode_at) begin
                    // Two instructions in a row begin at the same address: a
                    // jump to itself. The program will never leave it.
                    stuck = 1;
                end
                opcode_at = address;
                if (address == TEST && began == 0) begin
                    began = cycle;
                    // The copy must be the test, byte for byte, except the
                    // two bytes of the jump we changed.
                    different = 0;
                    for (n = 16'h000A; n < 16'h3900; n = n + 1) begin
                        if ((n < 16'h0100 || n >= 16'h0200)
                            && dut.the_ram.cells[n] !== program[n]
                            && n != SUCCESS + 1 && n != SUCCESS + 2) begin
                            different = different + 1;
                        end
                    end
                    $display("cycle %9d: the copy is done; the test begins at %h (the RAM holds it: %0d bytes different)",
                             cycle, address, different);
                    if (different != 0) errors = errors + 1;
                end
                if (address == SUCCESS && reached == 0) begin
                    reached = cycle;
                    $display("cycle %9d: the test reaches %h, where it ends when all went well", cycle, address);
                end
            end
            if (write && address == 16'h0200 && began != 0) begin
                part = data_out;
                $display("cycle %9d: part %h of the test begins", cycle, data_out);
            end
            if (write && address == 16'h8000) begin
                $display("cycle %9d: %h is written to the LEDs", cycle, data_out);
                if (reached != 0) shown = cycle;
            end
        end
    end

    initial begin
        wait (stuck || shown > 0 || cycle >= LIMIT);
        @(negedge clk);
        if (stuck) begin
            $display("FAIL: computer, the test stopped at %h, in part %h, after %0d cycles", opcode_at, part, cycle);
            $display("      A = %h  X = %h  Y = %h  S = %h  P = %b (N V - - D I Z C)", dut.processor.a,
                     dut.processor.x, dut.processor.y, dut.processor.s,
                     {dut.processor.negative, dut.processor.overflow, 2'b00, dut.processor.decimal,
                      dut.processor.interrupt_disable, dut.processor.zero, dut.processor.carry});
            $fatal;
        end else if (cycle >= LIMIT) begin
            $display("FAIL: computer, still running after %0d cycles, pc = %h", cycle, dut.processor.pc);
            $fatal;
        end else if (errors != 0) begin
            $display("FAIL: computer, the copy is not the test");
            $fatal;
        end else if (leds !== 6'd1) begin
            $display("FAIL: computer, the LEDs show %b, expected 000001", leds);
            $fatal;
        end else begin
            $display("PASS: computer, the functional test of Klaus Dormann went well: from $0400 to $3469 in %0d cycles; the LEDs show 1 at cycle %0d; %0d instructions",
                     reached - began, shown, instructions);
            $finish;
        end
    end
endmodule
