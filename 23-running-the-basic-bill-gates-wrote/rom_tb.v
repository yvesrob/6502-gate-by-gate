// Chapter 23 uses the rom_tb from chapter 8. This file is a copy of it, unchanged.
// Chapter 8, test bench for rom.v: every byte must be the one of the file,
// and it must come out one tick after its address, not before.
`timescale 1ns/1ns
module rom_tb;
    reg         clk = 0;
    reg  [13:0] address = 0;
    wire [7:0]  data;

    rom dut (
        .clk     (clk),
        .address (address),
        .data    (data)
    );

    // The test bench reads the same file on its own, to know what to expect.
    reg [7:0] expected [0:16383];
    initial begin
        $readmemh("rom.hex", expected);
    end

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer n;
    integer checked = 0;
    integer errors  = 0;
    reg [7:0] shown;        // what the ROM was showing before we asked

    // Ask for one byte. Until the tick, data must not move. After it, data
    // must be the byte of the file.
    task read_and_check;
        input [13:0] wanted;
        begin
            shown   = data;
            address = wanted;
            #2;
            if (data !== shown) begin
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
        $dumpfile("rom_tb.vcd");
        $dumpvars(0, rom_tb);

        @(negedge clk);

        // The eleven bytes of our program, to look at, here and in the waveform.
        for (n = 0; n < 11; n = n + 1) begin
            read_and_check(n);
            $display("address %2d: %h", address, data);
        end
        $dumpoff;

        // Then all of them, from the last to the first.
        for (n = 16383; n >= 0; n = n - 1) begin
            read_and_check(n);
        end

        if (errors == 0) begin
            $display("PASS: rom, %0d bytes read, each one tick after its address", checked);
            $finish;
        end else begin
            $display("FAIL: rom, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
