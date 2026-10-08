// Chapter 5, test bench for tmds.v. It plays the part of the monitor: it takes
// the ten bits, finds the byte back, and keeps count of the 1s and the 0s.
`timescale 1ns/1ns
module tmds_tb;
    reg        clk     = 0;
    reg  [7:0] data    = 0;
    reg  [1:0] control = 0;
    reg        visible = 0;
    wire [9:0] code;

    tmds dut (
        .clk     (clk),
        .data    (data),
        .control (control),
        .visible (visible),
        .code    (code)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // What a monitor does with ten bits: it finds the byte back.
    reg [7:0] plain;        // the eight bits, the right way up again
    reg [7:0] decoded;      // the byte
    integer   k;

    task decode;
        input [9:0] received;
        begin
            // Bit 9 says whether the eight bits were sent upside down.
            plain = received[9] ? ~received[7:0] : received[7:0];
            // Bit 8 says how they were chained: 1 for XOR, 0 for XNOR.
            // To undo the chain, combine each bit with its neighbor once more.
            decoded[0] = plain[0];
            for (k = 1; k < 8; k = k + 1) begin
                decoded[k] = received[8] ?  (plain[k] ^ plain[k - 1])
                                         : ~(plain[k] ^ plain[k - 1]);
            end
        end
    endtask

    // What the test bench counts.
    integer ones         = 0;       // the 1s in the code we are looking at
    integer changes      = 0;       // the places where a bit differs from the next one
    integer most_changes = 0;       // the largest number of changes seen in one code
    integer tally        = 0;       // 1s minus 0s, since the last pause
    integer highest      = 0;       // the two extremes that the tally has reached
    integer lowest       = 0;
    integer pauses       = 0;
    integer checked      = 0;
    integer errors       = 0;
    reg     after_pause  = 0;       // 1: the next code is the first one after a pause

    // One tick between two pictures: the two control bits must come out
    // as one of the four special codes. The test bench has its own copy of
    // the list: a test must know the right answers without asking the circuit.
    reg [9:0] expected;

    task pause;
        input [1:0] bits;
        begin
            control = bits;
            visible = 0;
            @(negedge clk);
            case (bits)
                2'b00: expected = 10'b1101010100;
                2'b01: expected = 10'b0010101011;
                2'b10: expected = 10'b0101010100;
                2'b11: expected = 10'b1010101011;
            endcase
            checked = checked + 1;
            if (code !== expected) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: control %b gave %b, expected %b", bits, code, expected);
            end
            tally       = 0;
            after_pause = 1;
            pauses      = pauses + 1;
        end
    endtask

    // Send one byte, decode what comes out, and count.
    task send;
        input [7:0] value;
        begin
            data    = value;
            visible = 1;
            @(negedge clk);
            checked = checked + 1;

            // The byte must come back.
            decode(code);
            if (decoded !== value) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: sent %h, the code %b gives back %h", value, code, decoded);
            end

            // How often does the signal change inside these ten bits?
            changes = 0;
            for (k = 0; k < 9; k = k + 1) begin
                if (code[k] !== code[k + 1]) changes = changes + 1;
            end
            if (changes > most_changes) most_changes = changes;

            // 1s minus 0s: ten bits, so the 0s are ten minus the 1s.
            ones = 0;
            for (k = 0; k < 10; k = k + 1) begin
                ones = ones + code[k];
            end
            tally = tally + ones - (10 - ones);
            if (tally > highest) highest = tally;
            if (tally < lowest)  lowest  = tally;

            // After a pause the encoder must start from a balance of zero. When
            // the balance is zero it always makes bit 9 the opposite of bit 8.
            if (after_pause && code[9] === code[8]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: after a pause, %h gave %b: the balance was not zero", value, code);
            end
            after_pause = 0;
        end
    endtask

    // Send one byte alone, after a pause, and print it.
    task show;
        input [7:0] value;
        begin
            pause(2'b00);
            send(value);
            $display("%h -> %b -> %h", value, code, decoded);
        end
    endtask

    integer    n;
    reg [31:0] random = 1;      // numbers that look random: see below

    initial begin
        $dumpfile("tmds_tb.vcd");
        $dumpvars(0, tmds_tb);

        // Between the pictures: the four special codes.
        pause(2'b00);
        pause(2'b01);
        pause(2'b10);
        pause(2'b11);
        $display("the four control codes:                 %0d error(s) so far", errors);

        // A few bytes to look at, here and in the waveform.
        show(8'h00);
        show(8'h01);
        show(8'h0F);
        show(8'h55);
        show(8'hFF);

        // Thousands of codes would make a huge waveform: it stops here.
        $dumpoff;

        // Every byte there is, each one alone after a pause.
        for (n = 0; n < 256; n = n + 1) begin
            pause(2'b00);
            send(n);
        end
        $display("256 bytes, each one alone:              %0d error(s) so far", errors);

        // Five long runs of the same byte, the hardest thing to keep in balance.
        pause(2'b00);
        for (n = 0; n < 1000; n = n + 1) send(8'h00);
        for (n = 0; n < 1000; n = n + 1) send(8'hFF);
        for (n = 0; n < 1000; n = n + 1) send(8'h55);
        for (n = 0; n < 1000; n = n + 1) send(8'hAA);
        for (n = 0; n < 1000; n = n + 1) send(8'h0F);
        $display("5000 bytes in five long runs:           %0d error(s) so far", errors);

        // A long picture of bytes that look random, with a pause now and then.
        // The recipe is a classic: multiply, add, and keep some bits from the
        // middle. The same starting number always gives the same list.
        for (n = 0; n < 100000; n = n + 1) begin
            random = random * 1103515245 + 12345;
            if (random[30:20] == 0) begin
                pause(random[9:8]);
            end
            send(random[23:16]);
        end
        $display("100000 bytes at random, %0d pauses in all: %0d error(s) so far", pauses, errors);

        // The two promises of the code.
        $display("changes inside one code:                %0d at most", most_changes);
        $display("1s minus 0s since a pause:              from %0d to %0d", lowest, highest);
        if (most_changes > 5) begin
            $display("wrong: a code with %0d changes, expected 5 at most", most_changes);
            errors = errors + 1;
        end
        if (highest > 8 || lowest < -8) begin
            $display("wrong: the balance went from %0d to %0d, expected -8 to 8", lowest, highest);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: tmds, %0d codes checked", checked);
            $finish;
        end else begin
            $display("FAIL: tmds, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
