// Chapter 23, test bench for board.v: what goes onto the board, pins and all.
// The PLL, the serializers and the pairs of pins are parts of the chip that
// the simulator does not know. The test bench gives it four stand-ins, at the
// end of this file, as in chapters 17 to 20. The rest is board.v as it is:
// one cycle of the processor every two ticks of the pixel clock, the six pins
// of the LEDs upside down (an LED is lit when its pin is LOW), button S2 on
// NMI, button S1 the reset, and the two pins of the serial link, where the
// Mac of mac.v types build/board.txt, through the flip-flop on pin 70, and
// hears every answer on pin 69: D000R, the two Returns, PRINT RND(1), and a
// program that never ends, RUN.
// While it runs, S2 bounces: several NMIs, and the BASIC must stop, write
// BREAK and OK, and keep its program: LIST must show it. Then S1 must start
// the monitor again: the LEDs back to 0, the colors painted again, the title
// and the prompt. Then D000R again, and PRINT RND(1): the BASIC starts afresh,
// and yet its first random number is not the one of the first start.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire       uart_rx;
    wire       uart_tx;
    reg        go   = 1;        // the Mac types once it hears the first prompt
    wire       done;
    wire [5:0] led;
    wire       tmds_clk_p;
    wire       tmds_clk_n;
    wire [2:0] tmds_d_p;
    wire [2:0] tmds_d_n;

    top dut (
        .clk        (clk),
        .btn1       (btn1),
        .btn2       (btn2),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .keyboard_rx (1'b1),        // pin 42, the keyboard's wire, at rest: nobody types on it here
        .led        (led),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n),
        .tmds_d_p   (tmds_d_p),
        .tmds_d_n   (tmds_d_n)
    );

    mac #(.FILE("board.txt")) the_mac (
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
            $display("tick %9d: the pins show %b, the LEDs show %2d", ticks, led, ~led);
            pins_before = led;
        end
        if (dut.step && ~dut.reset) begin
            if (address == 16'hFFFA && ~write) nmis = nmis + 1;
            if (address == 16'h9C00 && write) begin
                painted = painted + 1;
                $display("tick %9d: the colors are painted (a write at $9C00)", ticks);
            end
        end
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

    // Typing a line by hand, after the Mac's file: a key, then its echo; at
    // the end, the Return, its line feed, and the computer ready again.
    task type_line(input [8 * 20 - 1:0] line, input integer size);
        integer q, heard_before;
        begin
            for (q = 0; q < size; q = q + 1) begin
                heard_before = the_mac.count;
                the_mac.send_byte(line[8 * (size - 1 - q) +: 8]);
                wait (the_mac.count > heard_before);
            end
            heard_before = the_mac.count;
            the_mac.send_byte(13);
            wait (the_mac.count > heard_before && the_mac.heard[the_mac.count - 1] == 10);
            wait (the_mac.ready(the_mac.count) || ticks > 49_000_000);
        end
    endtask

    // The text that the Mac heard from a place on, as a string, for $display.
    reg [8 * 200 - 1:0] text;
    task heard_from(input integer from);
        integer q;
        begin
            text = 0;
            for (q = from; q < the_mac.count && q < from + 200; q = q + 1)
                if (the_mac.heard[q] != 13 && the_mac.heard[q] != 10) text = {text[8 * 199 - 1:0], the_mac.heard[q]};
                else text = {text[8 * 199 - 1:0], "|"};
        end
    endtask

    // Where the Mac heard a text last, or -1.
    function integer last_heard(input [8 * 20 - 1:0] wanted, input integer size);
        integer p, q, same;
        begin
            last_heard = -1;
            for (p = 0; p + size <= the_mac.count; p = p + 1) begin
                same = 1;
                for (q = 0; q < size; q = q + 1)
                    if (the_mac.heard[p + q] !== wanted[8 * (size - 1 - q) +: 8]) same = 0;
                if (same) last_heard = p;
            end
        end
    endfunction

    // Where the Mac heard a text first, or -1.
    function integer first_heard(input [8 * 20 - 1:0] wanted, input integer size);
        integer p, q, same;
        begin
            first_heard = -1;
            for (p = 0; p + size <= the_mac.count && first_heard < 0; p = p + 1) begin
                same = 1;
                for (q = 0; q < size; q = q + 1)
                    if (the_mac.heard[p + q] !== wanted[8 * (size - 1 - q) +: 8]) same = 0;
                if (same) first_heard = p;
            end
        end
    endfunction

    // The line the Mac heard from a place on, up to its carriage return, in text.
    task answer(input integer from);
        integer q;
        begin
            text = 0;
            for (q = from; q < the_mac.count && the_mac.heard[q] != 13; q = q + 1)
                text = {text[8 * 199 - 1:0], the_mac.heard[q]};
        end
    endtask

    integer nmis_before;
    integer painted_before;
    integer count_before;
    integer run_at;
    integer break_at;
    integer first_rnd;
    integer second_rnd;
    integer k;
    integer title_wrong = 0;
    reg [5:0] held;
    reg [8 * 24 - 1:0] rnd1;
    reg [8 * 24 - 1:0] rnd2;
    localparam [8 * 28 - 1:0] TITLE = {"Our Own 6502, Gate by Gate", 8'd13, 8'd10};

    initial begin
        // The Mac types board.txt; the last line, RUN, starts a program that
        // never ends. When the Mac has heard 300 bytes after RUN, S2.
        wait (the_mac.keys == the_mac.length + 1);     // Escape, then every key of the file
        run_at = the_mac.count;
        wait (the_mac.count > run_at + 300);
        $display("tick %9d: the program runs; S2 pressed, with a bounce of 400 ticks", ticks);
        nmis_before = nmis;
        bouncing(1, 400);
        #(2000 * 40);
        bouncing(0, 400);
        $display("tick %9d: S2 let go; %0d NMIs", ticks, nmis - nmis_before);
        if (nmis - nmis_before < 2) begin
            $display("wrong: a bouncing button should make several NMIs at this speed");
            errors = errors + 1;
        end
        wait (done || ticks > 49_000_000);
        break_at = last_heard({8'd13, 8'd10, "BREAK IN "}, 11);
        heard_from(break_at + 2);
        $display("tick %9d: the Mac has typed board.txt, %0d late; after S2 it hears: %0s", ticks, the_mac.late, text);
        if (!done || the_mac.late != 0 || break_at < run_at) begin
            $display("wrong: no BREAK after S2");
            errors = errors + 1;
        end
        count_before = the_mac.count;
        type_line("LIST", 4);
        heard_from(count_before);
        $display("tick %9d: LIST: %0s", ticks, text);
        if (last_heard(" 20 GOTO 10", 11) < count_before) begin
            $display("wrong: after the BREAK, LIST does not show the program");
            errors = errors + 1;
        end

        // S1 held: everything freezes. Let go: the monitor again.
        btn1 = 1;
        $display("tick %9d: S1 held", ticks);
        held = led;
        #(20000 * 40);
        if (led !== held) begin
            $display("wrong: the pins moved while S1 was held");
            errors = errors + 1;
        end
        painted_before = painted;
        count_before = the_mac.count;
        btn1 = 0;
        $display("tick %9d: S1 let go", ticks);
        wait (the_mac.ready(the_mac.count) && the_mac.count > count_before || ticks > 49_000_000);
        $display("tick %9d: the Mac hears the prompt again", ticks);
        if (led !== 6'b111111) begin
            $display("wrong: after S1 the pins show %b, expected 111111", led);
            errors = errors + 1;
        end
        if (painted == painted_before) begin
            $display("wrong: after S1 the colors are not painted again");
            errors = errors + 1;
        end
        for (k = 0; k < 28; k = k + 1)
            if (the_mac.heard[count_before + k] !== TITLE[8 * (27 - k) +: 8]) title_wrong = title_wrong + 1;
        if (title_wrong != 0) begin
            $display("wrong: after S1 the Mac does not hear the title");
            errors = errors + 1;
        end

        // The BASIC again, from scratch, and its first random number.
        type_line("D000R", 5);
        type_line("", 0);
        type_line("", 0);
        type_line("PRINT RND(1)", 12);
        first_rnd = first_heard({"PRINT RND(1)", 8'd13, 8'd10}, 14);
        second_rnd = last_heard({"PRINT RND(1)", 8'd13, 8'd10}, 14);
        answer(first_rnd + 14);
        rnd1 = text[8 * 24 - 1:0];
        answer(second_rnd + 14);
        rnd2 = text[8 * 24 - 1:0];
        $display("tick %9d: PRINT RND(1) after the first start: %0s; after S1 and D000R: %0s", ticks, rnd1, rnd2);
        if (first_rnd == second_rnd || rnd1 == rnd2) begin
            $display("wrong: the same first random number after S1");
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
            $display("PASS: board, one cycle every two ticks of the pixel clock; board.txt typed through pins 70 and 69; S2 with its bounces stops the program, which LIST still shows; S1 starts the monitor again, and D000R the BASIC, by tick %0d",
                     ticks);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;
        end
    end

    // A limit, as in every test bench of a processor.
    initial begin
        #(50_000_000 * 40);
        $display("FAIL: board, still running after 50 million ticks");
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
