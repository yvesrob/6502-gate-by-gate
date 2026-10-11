// Chapter 9 uses the computer_tb from chapter 8. This file is a copy of it, unchanged.
// Chapter 8, test bench for the whole computer: the processor must fetch the
// bytes of the program in order, starting at $C000, one in each cycle, and
// keep each of them.
`timescale 1ns/1ns
module computer_tb;
    reg         clk   = 0;
    reg         reset = 0;
    wire        step;
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
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // The test bench reads the file of the ROM on its own, to know what to expect.
    reg [7:0] expected [0:16383];
    initial begin
        $readmemh("rom.hex", expected);
    end

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // A flip-flop of the test bench's own: was there a step at the last tick?
    reg stepped = 0;
    always @(posedge clk) begin
        stepped <= step & ~reset;
    end

    integer cycle   = 0;        // cycles since the processor started
    integer checked = 0;
    integer errors  = 0;
    integer shown   = 11;       // how many cycles to print
    reg     asked   = 0;        // 1 once the processor has asked for its first byte
    reg [15:0] expected_address;
    reg [7:0]  fetched;         // the byte that the last cycle brought

    // We look at the bus half-way between two ticks, when nothing moves.
    always @(negedge clk) begin
        // A step has just been taken.
        if (stepped & ~reset) begin
            // If a cycle ended there, the processor must have kept its byte.
            // A test bench can look inside the circuit it tests: this is the
            // register opcode, in the instance processor, in the instance dut.
            if (asked && dut.processor.opcode !== fetched) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: after cycle %0d the processor holds %h, the bus gave %h",
                                           cycle, dut.processor.opcode, fetched);
            end
            // The very first step only asks for the first byte.
            asked = 1;
        end

        // A step is coming at the next tick: this is the end of a cycle, and
        // the byte the processor asked for must be there.
        if (step & ~reset & asked) begin
            cycle = cycle + 1;
            expected_address = 16'hC000 + cycle - 1;
            if (cycle <= shown) begin
                $display("cycle %2d: address %h, byte %h", cycle, address, data_in);
            end
            checked = checked + 1;
            // The bytes of the program, in order, from $C000 on.
            if (address !== expected_address) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: cycle %0d reads at %h, expected %h",
                                           cycle, address, expected_address);
            end
            if (data_in !== expected[cycle - 1]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: cycle %0d read %h, the file says %h",
                                           cycle, data_in, expected[cycle - 1]);
            end
            if (write !== 1'b0) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: the processor writes during cycle %0d", cycle);
            end
            fetched = data_in;
        end
    end

    // A test bench that waits for a processor needs a time limit. If the
    // cycles it is waiting for never come, it gives up after 10,000 ticks.
    initial begin
        #100000;
        $display("FAIL: computer, still waiting after 10,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Eleven cycles to look at: the eleven bytes of the program.
        wait (cycle == 11);
        @(posedge clk);
        $dumpoff;

        // Let it run a little further, into the empty part of the ROM.
        wait (cycle == 100);
        @(posedge clk);
        @(negedge clk);

        // A reset sends the processor back to the first byte.
        // (The test bench moves reset just after a tick, as a flip-flop would.)
        $display("reset");
        @(posedge clk);
        #1 reset = 1;
        asked    = 0;
        cycle    = 0;
        shown    = 3;
        repeat (3) @(posedge clk);
        #1 reset = 0;
        wait (cycle == 11);
        @(posedge clk);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles, the program read in order from C000", checked);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
