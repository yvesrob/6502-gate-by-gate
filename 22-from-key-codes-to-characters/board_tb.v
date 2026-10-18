// Chapter 22, test bench for board.v: what goes onto the board, pins and all.
// The PLL, the serializers and the pairs of pins are parts of the chip that
// the simulator does not know. The test bench gives it four stand-ins, at the
// end of this file, as in chapters 17 to 21. The rest is board.v as it is:
// one cycle of the processor every two ticks of the pixel clock, the six pins
// of the LEDs upside down (an LED is lit when its pin is LOW), button S2 on
// NMI, button S1 the reset, the serial link to the Mac on pins 70 and 69, and
// pin 42, where the keyboard's module of ch9350.v sends its frames, through
// the flip-flop. The module plays its shorter story (QUICK): it starts, and
// someone types two lines to the monitor, c108.c10f and 8000: 15.
// While the second line is typed, S2 bounces: several NMIs, which only add to
// FAST. Then the Mac types the lines of readback.txt on pin 70. At the end,
// the Mac must have heard the whole conversation, and the LEDs must show 15.
// Then S1 must start everything again: the colors painted again, the title
// and the prompt sent to the Mac again, the LEDs off.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire       uart_rx;
    wire       uart_tx;
    wire       keyboard_rx;
    reg        typing = 0;      // the person may begin to type
    wire       typed_all;
    wire [3:0] phase;
    reg        go   = 0;        // the Mac may begin
    wire       done;
    wire [5:0] led;
    wire       tmds_clk_p;
    wire       tmds_clk_n;
    wire [2:0] tmds_d_p;
    wire [2:0] tmds_d_n;

    top dut (
        .clk         (clk),
        .btn1        (btn1),
        .btn2        (btn2),
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),
        .keyboard_rx (keyboard_rx),
        .led         (led),
        .tmds_clk_p  (tmds_clk_p),
        .tmds_clk_n  (tmds_clk_n),
        .tmds_d_p    (tmds_d_p),
        .tmds_d_n    (tmds_d_n)
    );

    ch9350 #(.QUICK(1), .WIRE("wire-board.txt")) module_and_keyboard (
        .go    (typing),
        .tx    (keyboard_rx),
        .done  (typed_all),
        .phase (phase)
    );

    mac #(.FILE("readback.txt")) the_mac (
        .go   (go),
        .tx   (uart_tx),
        .rx   (uart_rx),
        .done (done)
    );

    // One tick (rising edge) every 40 ns, as for the pixel clock.
    always #20 clk = ~clk;

    // In the chip the memories start at zero; in the simulator they start unknown.
    integer n;
    initial begin
        for (n = 0; n < 32768; n = n + 1) dut.our_computer.the_ram.cells[n] = 8'h00;
        for (n = 0; n < 8192; n = n + 1) dut.our_computer.the_bitmap.cells[n] = 8'h00;
        for (n = 0; n < 1024; n = n + 1) dut.our_computer.the_colors.cells[n] = 8'h00;
    end

    // The conversation the Mac must hear, written by hand.
    reg [7:0] text [0:1023];
    integer   length = 0;
    task say(input [8 * 48 - 1:0] what);    // some text, its first zero bytes left out
        integer j;
        reg     begun;
        begin
            begun = 0;
            for (j = 47; j >= 0; j = j - 1) begin
                if (what[8 * j +: 8] != 0) begun = 1;
                if (begun) begin
                    text[length] = what[8 * j +: 8];
                    length = length + 1;
                end
            end
        end
    endtask
    task say_line(input [8 * 48 - 1:0] what);
        begin
            say(what);
            say({8'd13, 8'd10});
        end
    endtask
    task say_title;
        begin
            say_line("Our Own 6502, Gate by Gate");
            say_line("Chapter 22: From Key Codes to Characters");
            say("*");
        end
    endtask

    // What the test bench watches, inside the board: the pixel clock, the
    // steps of the timer, and the bus of the computer.
    wire        pixel_clk;
    wire [15:0] address;
    wire        write;
    assign pixel_clk = dut.pixel_clk;
    assign address   = dut.our_computer.address;
    assign write     = dut.our_computer.write;

    integer ticks      = 0;     // ticks of the pixel clock
    integer last_step  = 0;
    integer steps      = 0;
    integer gaps       = 0;     // steps that did not come two ticks after the one before
    integer nmis       = 0;     // NMIs taken: the vector at $FFFA read
    integer painted    = 0;     // writes at $9C00, the first cell of the colors
    integer errors     = 0;
    reg [5:0] pins_before = 6'b111111;

    always @(posedge pixel_clk) begin
        ticks = ticks + 1;
        if (dut.step) begin
            if (last_step != 0 && ticks - last_step != 2) gaps = gaps + 1;
            last_step = ticks;
            steps = steps + 1;
        end
    end

    always @(negedge pixel_clk) begin
        if (led !== pins_before) begin
            $display("tick %8d: the pins show %b, the LEDs show %h", ticks, led, ~led);
            pins_before = led;
        end
        if (dut.step && ~dut.reset) begin
            if (address == 16'hFFFA && ~write) nmis = nmis + 1;
            if (address == 16'h9C00 && write) begin
                painted = painted + 1;
                $display("tick %8d: the colors are painted (a write at $9C00)", ticks);
            end
        end
        // The person types once the Mac has heard the first prompt; the Mac,
        // once the person is done and the monitor has answered.
        if (!typing && the_mac.prompts == 1) typing = 1;
        if (typed_all && !go && the_mac.prompts == 3) go = 1;
    end

    // A button that bounces: for a while after it is pressed or let go, the
    // contact opens and closes again, every 7 ticks.
    task bouncing;
        input   level;      // where it ends
        input integer bounce;
        integer t;
        begin
            for (t = 0; t < bounce; t = t + 7) begin
                btn2 = ~btn2;
                #(7 * 40);
            end
            btn2 = level;
        end
    endtask

    integer    painted_before;
    integer    heard_before;
    integer    j, wrong_text;
    reg [5:0]  held;

    initial begin
        say_title;
        say_line("C108.C10F");
        say_line("C108: 38 44 44 7C 44 44 44 00");
        say("*"); say_line("8000: 15");
        say("*"); say_line("\\");                       // the Mac begins with Escape
        say("*"); say_line("0400.0401");
        say_line("0400: 00 00");
        say("*"); say_line("0500");
        say_line("0500: 00");
        say("*"); say_line("8000");
        say_line("8000: 15");
        say("*");

        // While the second line is typed: S2, with a bounce of 400 ticks.
        wait (phase == 3);
        $display("tick %8d: S2 pressed, with a bounce of 400 ticks", ticks);
        bouncing(1, 400);
        #(2000 * 40);
        bouncing(0, 400);
        $display("tick %8d: S2 let go; %0d NMIs", ticks, nmis);
        if (nmis < 2) begin
            $display("wrong: a bouncing button should make several NMIs at this speed");
            errors = errors + 1;
        end

        // The Mac has typed its lines and heard the last answer.
        wait (done && the_mac.count >= length);
        #(100_000);
        wrong_text = 0;
        for (j = 0; j < length; j = j + 1)
            if (j >= the_mac.count || the_mac.heard[j] !== text[j]) wrong_text = wrong_text + 1;
        $display("tick %8d: the module has sent %0d bytes through pin 42; the Mac typed %0d lines on pin 70 and heard %0d bytes on pin 69, %0d expected, %0d different",
                 ticks, module_and_keyboard.bytes, the_mac.lines, the_mac.count, length, wrong_text);
        if (the_mac.count != length || wrong_text != 0) errors = errors + 1;
        if (led !== ~6'h15) begin
            $display("wrong: at the end the pins show %b, expected %b", led, ~6'h15);
            errors = errors + 1;
        end

        // S1 held: everything freezes. Let go: the monitor again.
        btn1 = 1;
        $display("tick %8d: S1 held", ticks);
        held = led;
        heard_before = the_mac.count;
        #(20000 * 40);
        if (led !== held) begin
            $display("wrong: the pins moved while S1 was held");
            errors = errors + 1;
        end
        painted_before = painted;
        btn1 = 0;
        $display("tick %8d: S1 let go", ticks);
        say_title;
        wait (the_mac.count >= length || ticks > 19_900_000);
        #(100_000);
        wrong_text = 0;
        for (j = 0; j < 71; j = j + 1)
            if (the_mac.heard[heard_before + j] !== text[length - 71 + j]) wrong_text = wrong_text + 1;
        $display("tick %8d: after S1 the Mac heard %0d bytes, the title and the prompt are %0d; %0d different", ticks,
                 the_mac.count - heard_before, 71, wrong_text);
        if (the_mac.count - heard_before != 71 || wrong_text != 0) errors = errors + 1;
        if (led !== 6'b111111) begin
            $display("wrong: after S1 the pins show %b, expected 111111", led);
            errors = errors + 1;
        end
        if (painted == painted_before) begin
            $display("wrong: after S1 the colors are not painted again");
            errors = errors + 1;
        end
        if (gaps != 0) begin
            $display("wrong: %0d steps did not come two ticks after the one before", gaps);
            errors = errors + 1;
        end
        if (the_mac.broken != 0) begin
            $display("wrong: the Mac heard %0d bytes without their stop bit", the_mac.broken);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: board, one cycle every two ticks of the pixel clock; the keys typed through pin 42 and the lines typed through pin 70 answered on pin 69; S2 with its bounces changes nothing; S1 starts everything again");
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;
        end
    end

    // A limit, as in every test bench of a processor.
    initial begin
        #(20_000_000 * 40);
        $display("FAIL: board, still running after 20 million ticks");
        $fatal;
    end
endmodule

// The stand-ins for the parts of the chip that the simulator does not know.
// They keep the names and the pins of the real ones, so that board.v, pll.v
// and serializer.v are used as they are.

// The PLL: no multiplication; its output is its input, and it says it is
// locked after ten ticks.
module rPLL (CLKOUT, CLKOUTP, CLKOUTD, CLKOUTD3, LOCK, CLKIN, CLKFB, FBDSEL, IDSEL, ODSEL, DUTYDA, PSDA, FDLY,
             RESET, RESET_P);
    parameter FCLKIN    = "27";
    parameter IDIV_SEL  = 0;
    parameter FBDIV_SEL = 0;
    parameter ODIV_SEL  = 8;
    input  CLKIN, CLKFB, RESET, RESET_P;
    input  [5:0] FBDSEL, IDSEL, ODSEL;
    input  [3:0] DUTYDA, PSDA, FDLY;
    output CLKOUT, CLKOUTP, CLKOUTD, CLKOUTD3;
    output reg LOCK = 0;
    integer count = 0;
    always @(posedge CLKIN) begin
        if (count < 10) count = count + 1;
        else LOCK <= 1;
    end
    assign CLKOUT   = CLKIN;
    assign CLKOUTP  = 1'b0;
    assign CLKOUTD  = 1'b0;
    assign CLKOUTD3 = 1'b0;
endmodule

// The divider: no division; its output is its input, once RESETN is 1.
module CLKDIV (CLKOUT, HCLKIN, RESETN, CALIB);
    parameter DIV_MODE = "2";
    input  HCLKIN, RESETN, CALIB;
    output CLKOUT;
    assign CLKOUT = HCLKIN & RESETN;
endmodule

// The serializer: it sends nothing.
module OSER10 (D9, D8, D7, D6, D5, D4, D3, D2, D1, D0, FCLK, PCLK, RESET, Q);
    input  D9, D8, D7, D6, D5, D4, D3, D2, D1, D0, FCLK, PCLK, RESET;
    output Q;
    assign Q = 1'b0;
endmodule

// A pair of pins: the signal, and its opposite.
module TLVDS_OBUF (I, O, OB);
    input  I;
    output O, OB;
    assign O  = I;
    assign OB = ~I;
endmodule
