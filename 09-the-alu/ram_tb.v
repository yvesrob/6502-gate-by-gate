// Chapter 9 uses the ram_tb from chapter 8. This file is a copy of it, unchanged.
// Chapter 8, test bench for ram.v: a byte we write must come back when we
// read it, one tick after its address; a cell we did not write must not
// change; and nothing must be written while write is 0.
`timescale 1ns/1ns
module ram_tb;
    reg         clk     = 0;
    reg  [14:0] address = 0;
    reg         write   = 0;
    reg  [7:0]  data_in = 0;
    wire [7:0]  data_out;

    ram dut (
        .clk      (clk),
        .address  (address),
        .write    (write),
        .data_in  (data_in),
        .data_out (data_out)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    integer n;
    integer checked = 0;
    integer errors  = 0;
    reg [7:0] neighbor;     // what cell 101 gave, kept to be printed

    // Store one byte: the address, the byte and write are taken at the tick.
    task store;
        input [14:0] where;
        input [7:0]  what;
        begin
            address = where;
            data_in = what;
            write   = 1;
            @(negedge clk);
            write   = 0;
        end
    endtask

    // Read one byte and compare it with the value we expect.
    task read_and_check;
        input [14:0] where;
        input [7:0]  expected;
        begin
            address = where;
            @(negedge clk);
            checked = checked + 1;
            if (data_out !== expected) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: address %0d gave %h, expected %h",
                                           where, data_out, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("ram_tb.vcd");
        $dumpvars(0, ram_tb);

        @(negedge clk);

        // A cell nobody has written: the simulator does not know what it holds.
        address = 100;
        @(negedge clk);
        $display("address 100, never written:  %h", data_out);

        // Write 42 there and read it back.
        store(100, 8'h42);
        read_and_check(100, 8'h42);
        $display("address 100, after a write:  %h", data_out);

        // Put another byte on data_in, but leave write at 0: nothing happens.
        data_in = 8'h99;
        @(negedge clk);
        read_and_check(100, 8'h42);
        $display("address 100, write at 0:     %h", data_out);

        // Write a neighbor. The first cell keeps its byte.
        store(101, 8'h07);
        read_and_check(101, 8'h07);
        neighbor = data_out;
        read_and_check(100, 8'h42);
        $display("address 101: %h, address 100: %h", neighbor, data_out);

        // Write over it.
        store(100, 8'hFF);
        read_and_check(100, 8'hFF);
        $display("address 100, written again:  %h", data_out);
        $dumpoff;

        // Now the whole memory. Each cell gets the low byte of its address
        // XOR the high byte: two cells whose addresses differ by one bit
        // never hold the same byte. Then all of them are read back, from the
        // last to the first.
        for (n = 0; n < 32768; n = n + 1) begin
            store(n, n ^ (n >> 8));     // only the eight low bits are kept
        end
        for (n = 32767; n >= 0; n = n - 1) begin
            read_and_check(n, n ^ (n >> 8));
        end

        if (errors == 0) begin
            $display("PASS: ram, %0d bytes read back", checked);
            $finish;
        end else begin
            $display("FAIL: ram, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
