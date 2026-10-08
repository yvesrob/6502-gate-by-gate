// Chapter 6, test bench for memory.v: the byte must be the one of the file,
// and it must come out one tick after the address, not before.
`timescale 1ns/1ns
module memory_tb;
    reg         clk = 0;
    reg  [12:0] address = 0;
    wire [7:0]  data;

    // The memory of the colors: 1,000 bytes, read from colors.hex.
    memory #(.WORDS(1000), .FILE("colors.hex")) dut (
        .clk     (clk),
        .address (address),
        .data    (data)
    );

    // The test bench reads the same file on its own, to know what to expect.
    reg [7:0] expected [0:999];
    initial begin
        $readmemh("colors.hex", expected);
    end

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer n;
    integer checked = 0;
    integer errors  = 0;
    reg [7:0] before;       // what the memory was showing before we asked

    // Ask for one byte. Until the tick, data must not move. After it, data
    // must be the byte of the file.
    task read_and_check;
        input [12:0] wanted;
        begin
            before  = data;
            address = wanted;
            #2;
            if (data !== before) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: data changed before the tick, at address %0d", wanted);
            end
            @(negedge clk);
            checked = checked + 1;
            if (data !== expected[wanted]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: address %0d gave %h, expected %h",
                                           wanted, data, expected[wanted]);
            end
        end
    endtask

    initial begin
        $dumpfile("memory_tb.vcd");
        $dumpvars(0, memory_tb);

        @(negedge clk);

        // A few bytes to look at, here and in the waveform.
        read_and_check(0);
        $display("address %4d: %h", address, data);
        read_and_check(45);
        $display("address %4d: %h", address, data);
        read_and_check(213);
        $display("address %4d: %h", address, data);
        read_and_check(890);
        $display("address %4d: %h", address, data);
        $dumpoff;

        // Then all of them, from the last to the first.
        for (n = 999; n >= 0; n = n - 1) begin
            read_and_check(n);
        end

        if (errors == 0) begin
            $display("PASS: memory, %0d bytes read, each one tick after its address", checked);
            $finish;
        end else begin
            $display("FAIL: memory, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
