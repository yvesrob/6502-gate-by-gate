// Chapter 10, test bench for the whole computer. It watches the bus, and
// compares every cycle with what a 6502 does with our program. It follows
// the six LEDs as well: they must count.
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
        .leds     (leds),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // One tick (rising edge) every 10 ns: at 5, 15, 25...
    always #5 clk = ~clk;

    // What the bus of a 6502 shows while it runs our program, worked out
    // from the tables of cycles of the document "64doc": the address, whether
    // the processor writes, and the byte. Two cycles for LDA #0, then the
    // eleven cycles of one lap of the loop, which come back forever.
    reg [15:0]   expected_address [1:13];
    reg          expected_write   [1:13];
    reg [7:0]    expected_byte    [1:13];
    reg [8*27:1] comment          [1:13];

    task expect_cycle;
        input integer    which;
        input [15:0]     the_address;
        input            the_write;
        input [7:0]      the_byte;
        input [8*27:1]   the_comment;
        begin
            expected_address[which] = the_address;
            expected_write[which]   = the_write;
            expected_byte[which]    = the_byte;
            comment[which]          = the_comment;
        end
    endtask

    initial begin
        //           cycle  address  write  byte
        expect_cycle( 1, 16'hC000, 0, 8'hA9, "LDA #0");
        expect_cycle( 2, 16'hC001, 0, 8'h00, "  the value");
        expect_cycle( 3, 16'hC002, 0, 8'h8D, "STA $8000");
        expect_cycle( 4, 16'hC003, 0, 8'h00, "  the address, low byte");
        expect_cycle( 5, 16'hC004, 0, 8'h80, "  the address, high byte");
        expect_cycle( 6, 16'h8000, 1, 8'h00, "  A, on its way to the LEDs");   // the byte is the count
        expect_cycle( 7, 16'hC005, 0, 8'h18, "CLC");
        expect_cycle( 8, 16'hC006, 0, 8'h69, "  the next byte, not used");
        expect_cycle( 9, 16'hC006, 0, 8'h69, "ADC #1");
        expect_cycle(10, 16'hC007, 0, 8'h01, "  the value");
        expect_cycle(11, 16'hC008, 0, 8'h4C, "JMP $C002");
        expect_cycle(12, 16'hC009, 0, 8'h02, "  the address, low byte");
        expect_cycle(13, 16'hC00A, 0, 8'hC0, "  the address, high byte");
    end

    // The state of the processor, as a name to print. A test bench can look
    // inside the circuit it tests: this is the register state, in the
    // instance processor, in the instance dut. The numbers are those of cpu.v.
    reg [8*8:1] state_name;
    always @(*) begin
        case (dut.processor.state)
            0:       state_name = "STARTING";
            1:       state_name = "OPCODE";
            2:       state_name = "OPERAND";
            3:       state_name = "HIGH";
            4:       state_name = "STORE";
            default: state_name = "?";
        endcase
    end

    integer cycle   = 0;        // cycles since the processor started
    integer place   = 0;        // where this cycle is in the table: 1 to 13
    integer laps    = 0;        // how many times the program has stored A
    integer checked = 0;        // cycles checked since the beginning
    integer errors  = 0;
    integer shown   = 24;       // how many cycles to print
    reg     asked   = 0;        // 1 once the processor has asked for its first byte
    reg [7:0] count = 0;        // the byte that the program must store next
    reg [7:0] the_byte;
    reg [7:0] wanted;

    // We look at the bus half-way between two ticks, when nothing moves. A
    // step is coming at the next tick: this is the end of a cycle.
    always @(negedge clk) begin
        if (step & ~reset) begin
            if (asked) begin
                cycle = cycle + 1;
                // After the first two cycles the program is a loop: the same
                // eleven lines of the table, lap after lap.
                place    = (cycle <= 13) ? cycle : 3 + (cycle - 3) % 11;
                the_byte = write ? data_out : data_in;
                wanted   = expected_write[place] ? count : expected_byte[place];
                if (cycle <= shown) begin
                    $display("cycle %2d: %-8s %h %s %h   %0s", cycle, state_name, address,
                             write ? "write" : "read ", the_byte, comment[place]);
                end
                checked = checked + 1;
                if (address !== expected_address[place] || write !== expected_write[place]
                                                        || the_byte !== wanted) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("wrong: cycle %0d is %h %s %h, expected %h %s %h",
                                               cycle, address, write ? "write" : "read ", the_byte,
                                               expected_address[place],
                                               expected_write[place] ? "write" : "read ", wanted);
                end
                // A byte has been stored: one more lap, and the count goes up.
                if (write) begin
                    laps = laps + 1;
                    if (laps == 3 || laps == 4 || laps == 64 || laps == 65 || laps == 256
                                  || laps == 257 || laps == 258 || laps == 600) begin
                        $display("lap %3d: the program stores %3d, the LEDs show %b", laps, data_out, leds);
                    end
                    count = count + 8'd1;
                end
            end
            // The very first step only asks for the first byte.
            asked = 1;
        end
    end

    // The LEDs. At every tick the test bench does what the computer should
    // do: if the processor is writing at $8000, the six low bits of the byte
    // are what the LEDs must show from then on. They must show nothing else.
    reg [5:0] expected_leds = 0;
    always @(posedge clk) begin
        if (write & (address == 16'h8000)) begin
            expected_leds = data_out[5:0];
        end
    end
    always @(negedge clk) begin
        if (leds !== expected_leds) begin
            errors = errors + 1;
            if (errors <= 10) $display("wrong: the LEDs show %b, expected %b", leds, expected_leds);
        end
    end

    // A test bench that waits for a processor needs a time limit. If the
    // laps it is waiting for never come, it gives up after 100,000 ticks.
    initial begin
        #1000000;
        $display("FAIL: computer, still waiting after 100,000 ticks");
        $fatal;
    end

    initial begin
        $dumpfile("computer_tb.vcd");
        $dumpvars(0, computer_tb);

        // Twenty-four cycles to look at: LDA #0, then two laps of the loop.
        wait (cycle == 24);
        @(posedge clk);
        $dumpoff;

        // Then 600 laps: the count goes past 255 twice.
        wait (laps == 600);

        // A reset starts the program again, and the count with it. It comes
        // at the worst moment: the processor has just begun to store a byte.
        // (The test bench moves reset just after a tick, as a flip-flop would.)
        wait (place == 5);
        $display("reset");
        @(posedge clk);
        #1 reset = 1;
        asked    = 0;
        cycle    = 0;
        place    = 0;
        laps     = 0;
        count    = 0;
        shown    = 6;
        repeat (3) @(posedge clk);
        #1 reset = 0;
        wait (laps == 1);
        @(posedge clk);
        @(negedge clk);

        if (errors == 0) begin
            $display("PASS: computer, %0d cycles as a 6502 does them, and LEDs that count", checked);
            $finish;
        end else begin
            $display("FAIL: computer, %0d error(s)", errors);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
