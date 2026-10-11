// Chapter 9, test bench for alu.v: a few operations that we can read, then
// every operation on every pair of bytes, with the carry at 0 and at 1.
`timescale 1ns/1ns
module alu_tb;
    `include "alu_operations.vh"

    reg  [3:0] operation;
    reg  [7:0] a;
    reg  [7:0] b;
    reg        carry_in;
    wire [7:0] result;
    wire       carry_out;
    wire       overflow;
    wire       negative;
    wire       zero;

    alu dut (
        .operation (operation),
        .a         (a),
        .b         (b),
        .carry_in  (carry_in),
        .result    (result),
        .carry_out (carry_out),
        .overflow  (overflow),
        .negative  (negative),
        .zero      (zero)
    );

    integer first;
    integer second;
    integer carry;
    integer which;
    integer checked = 0;
    integer errors  = 0;

    // The name of the operation, as text, to print it: room for twelve
    // characters of eight bits each. This block runs again each time
    // operation changes, so name always goes with it.
    reg [8*12:1] name;
    always @(*) begin
        case (operation)
            ALU_PASS:         name = "PASS";
            ALU_ADD:          name = "ADD";
            ALU_SUBTRACT:     name = "SUBTRACT";
            ALU_COMPARE:      name = "COMPARE";
            ALU_AND:          name = "AND";
            ALU_OR:           name = "OR";
            ALU_XOR:          name = "XOR";
            ALU_SHIFT_LEFT:   name = "SHIFT_LEFT";
            ALU_ROTATE_LEFT:  name = "ROTATE_LEFT";
            ALU_SHIFT_RIGHT:  name = "SHIFT_RIGHT";
            ALU_ROTATE_RIGHT: name = "ROTATE_RIGHT";
            ALU_INCREMENT:    name = "INCREMENT";
            ALU_DECREMENT:    name = "DECREMENT";
            default:          name = "?";
        endcase
    end

    // Do one operation and print it: each byte in decimal and in binary,
    // then the four flags. C is carry_out, V is overflow, N is negative
    // and Z is zero: the letters the 6502 gives them.
    task show;
        input [3:0] in_operation;
        input [7:0] in_a;
        input [7:0] in_b;
        input       in_carry;
        begin
            operation = in_operation;
            a         = in_a;
            b         = in_b;
            carry_in  = in_carry;
            #10;
            $display("%-12s  %3d %b  %3d %b   %b    %3d %b   %b %b %b %b",
                     name, a, a, b, b, carry_in, result, result,
                     carry_out, overflow, negative, zero);
        end
    endtask

    // What the test bench expects. It is worked out with ordinary numbers and
    // none of the tricks of the circuit: here a subtraction is a subtraction,
    // and a shift to the left is a multiplication by two.
    integer value;              // the true answer, which may not fit in a byte
    integer signed_a;           // a and b read as signed bytes, -128 to 127
    integer signed_b;
    integer signed_value;       // the true answer for those two
    reg [7:0] expected_result;
    reg       expected_carry;
    reg       expected_overflow;
    reg       expected_negative;
    reg       expected_zero;
    reg       has_carry;        // does this operation have a carry to check?
    reg       has_overflow;     // and an overflow?

    task check;
        begin
            #1;
            signed_a = (a > 127) ? a - 256 : a;
            signed_b = (b > 127) ? b - 256 : b;
            has_carry         = 0;
            has_overflow      = 0;
            expected_carry    = 0;
            expected_overflow = 0;
            case (operation)
                ALU_PASS: begin
                    value = a;
                end
                ALU_ADD: begin
                    value             = a + b + carry_in;
                    signed_value      = signed_a + signed_b + carry_in;
                    expected_carry    = (value > 255);
                    expected_overflow = (signed_value > 127) || (signed_value < -128);
                    has_carry         = 1;
                    has_overflow      = 1;
                end
                ALU_SUBTRACT: begin
                    // With carry_in at 0, one more is taken away: a borrow.
                    value             = a - b - (1 - carry_in);
                    signed_value      = signed_a - signed_b - (1 - carry_in);
                    expected_carry    = (value >= 0);       // 1: no need to borrow
                    expected_overflow = (signed_value > 127) || (signed_value < -128);
                    has_carry         = 1;
                    has_overflow      = 1;
                end
                ALU_COMPARE: begin
                    value          = a - b;
                    expected_carry = (a >= b);
                    has_carry      = 1;
                end
                ALU_AND: value = a & b;
                ALU_OR:  value = a | b;
                ALU_XOR: value = a ^ b;
                ALU_SHIFT_LEFT: begin
                    value          = a * 2;
                    expected_carry = (value > 255);
                    has_carry      = 1;
                end
                ALU_ROTATE_LEFT: begin
                    value          = a * 2 + carry_in;
                    expected_carry = (value > 255);
                    has_carry      = 1;
                end
                ALU_SHIFT_RIGHT: begin
                    value          = a / 2;
                    expected_carry = a % 2;                 // what the division leaves
                    has_carry      = 1;
                end
                ALU_ROTATE_RIGHT: begin
                    value          = a / 2 + 128 * carry_in;
                    expected_carry = a % 2;
                    has_carry      = 1;
                end
                ALU_INCREMENT: value = a + 1;
                ALU_DECREMENT: value = a - 1;
            endcase

            // A byte keeps what is left of the true answer once every whole
            // 256 is gone: the remainder of a division by 256. Adding 256
            // first makes sure that we never divide a negative number.
            expected_result   = (value + 256) % 256;
            expected_negative = (expected_result > 127);
            expected_zero     = (expected_result == 0);

            checked = checked + 1;
            if (result !== expected_result
                || negative !== expected_negative
                || zero     !== expected_zero
                || (has_carry    && carry_out !== expected_carry)
                || (has_overflow && overflow  !== expected_overflow)) begin
                errors = errors + 1;
                // Print the first ten mistakes, not thousands of them. A dash
                // stands for a flag that this operation does not define.
                if (errors <= 10) begin
                    $display("wrong: %0s, a = %0d, b = %0d, carry_in = %b",
                             name, a, b, carry_in);
                    $display("       gave     %3d %b   C V N Z = %b %b %b %b",
                             result, result, carry_out, overflow, negative, zero);
                    $display("       expected %3d %b   C V N Z = %s %s %b %b",
                             expected_result, expected_result,
                             has_carry    ? (expected_carry    ? "1" : "0") : "-",
                             has_overflow ? (expected_overflow ? "1" : "0") : "-",
                             expected_negative, expected_zero);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        // A few operations to look at, here and in the waveform.
        $display("operation          a             b      carry_in   result      C V N Z");
        show(ALU_ADD,       23,  19, 0);
        show(ALU_ADD,       23,  19, 1);     // the carry coming in counts for one
        show(ALU_ADD,      200, 100, 0);     // 300 needs a ninth bit: carry
        show(ALU_ADD,      100,  50, 0);     // 150 is not a signed byte: overflow
        show(ALU_ADD,      156, 156, 0);     // -100 + -100: a carry and an overflow
        $display("");
        show(ALU_SUBTRACT,  42,  19, 1);
        show(ALU_SUBTRACT,  42,  19, 0);     // carry_in at 0 takes one more away
        show(ALU_SUBTRACT,  19,  42, 1);     // below zero: the carry comes out at 0
        show(ALU_SUBTRACT, 100, 156, 1);     // 100 - -100 is 200: overflow
        $display("");
        show(ALU_COMPARE,   42,  19, 0);     // larger: carry at 1
        show(ALU_COMPARE,   42,  42, 0);     // equal: carry at 1, and zero
        show(ALU_COMPARE,   19,  42, 0);     // smaller: carry at 0
        $display("");
        show(ALU_AND, 8'b11001100, 8'b10101010, 0);
        show(ALU_OR,  8'b11001100, 8'b10101010, 0);
        show(ALU_XOR, 8'b11001100, 8'b10101010, 0);
        $display("");
        show(ALU_SHIFT_LEFT,   8'b10010110, 0, 1);
        show(ALU_ROTATE_LEFT,  8'b10010110, 0, 1);
        show(ALU_SHIFT_RIGHT,  8'b10010110, 0, 1);
        show(ALU_ROTATE_RIGHT, 8'b10010110, 0, 1);
        $display("");
        show(ALU_INCREMENT, 255, 0, 0);      // 255 + 1 wraps around to 0
        show(ALU_DECREMENT,   0, 0, 0);      // and 0 - 1 to 255
        show(ALU_PASS,       42, 0, 0);
        $display("");

        // Nobody wants to scroll through 1,703,936 operations:
        // the waveform stops here, the test goes on.
        $dumpoff;

        // Now everything: 13 operations, 256 values for a, 256 for b, and
        // carry_in at 0 or 1.
        for (which = 0; which <= 12; which = which + 1) begin
            for (first = 0; first < 256; first = first + 1) begin
                for (second = 0; second < 256; second = second + 1) begin
                    for (carry = 0; carry < 2; carry = carry + 1) begin
                        operation = which;
                        a         = first;
                        b         = second;
                        carry_in  = carry;
                        check;
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("PASS: alu, %0d operations checked", checked);
            $finish;
        end else begin
            $display("FAIL: alu, %0d wrong answer(s) out of %0d", errors, checked);
            $fatal;     // stop, and tell the shell that something went wrong
        end
    end
endmodule
