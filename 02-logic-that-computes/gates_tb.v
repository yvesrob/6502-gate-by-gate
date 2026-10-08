// Chapter 2, test bench for gates.v: try the four possible inputs,
// print the truth table, and check every gate against the table we expect.
`timescale 1ns/1ns
module gates_tb;
    // The test bench plays the part of the buttons: it sets a and b itself.
    reg  a;
    reg  b;
    wire a_and_b;
    wire a_or_b;
    wire a_xor_b;
    wire a_nand_b;
    wire a_nor_b;
    wire a_xnor_b;

    // The circuit we are testing.
    gates dut (
        .a        (a),
        .b        (b),
        .a_and_b  (a_and_b),
        .a_or_b   (a_or_b),
        .a_xor_b  (a_xor_b),
        .a_nand_b (a_nand_b),
        .a_nor_b  (a_nor_b),
        .a_xnor_b (a_xnor_b)
    );

    integer errors = 0;

    // Set the two inputs, wait a little, print one row of the table,
    // and compare the six outputs with the six values we expect.
    task check;
        input in_a;
        input in_b;
        input want_and;
        input want_or;
        input want_xor;
        input want_nand;
        input want_nor;
        input want_xnor;
        begin
            a = in_a;
            b = in_b;
            #10;
            $display("%b %b |  %b   %b   %b    %b   %b    %b",
                     a, b, a_and_b, a_or_b, a_xor_b, a_nand_b, a_nor_b, a_xnor_b);
            // !== also catches an output that is unknown (x), not just a wrong one.
            if (a_and_b  !== want_and  || a_or_b  !== want_or  || a_xor_b  !== want_xor ||
                a_nand_b !== want_nand || a_nor_b !== want_nor || a_xnor_b !== want_xnor) begin
                $display("      ^ this row is wrong");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Record every signal, so we can look at the waveform afterwards.
        $dumpfile("gates_tb.vcd");
        $dumpvars(0, gates_tb);

        $display("a b | and or xor nand nor xnor");
        //    a  b    and or xor nand nor xnor
        check(0, 0,    0,  0,  0,   1,  1,   1);
        check(0, 1,    0,  1,  1,   1,  0,   0);
        check(1, 0,    0,  1,  1,   1,  0,   0);
        check(1, 1,    1,  1,  0,   0,  0,   1);

        if (errors == 0) begin
            $display("PASS: gates, 4 rows checked");
            $finish;
        end else begin
            $display("FAIL: gates, %0d wrong row(s) out of 4", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
