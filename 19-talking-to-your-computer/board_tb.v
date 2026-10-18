// Chapter 19, test bench for board.v: what goes onto the board, pins and all.
// The PLL, the serializers and the pairs of pins are parts of the chip that
// the simulator does not know. The test bench gives it four stand-ins, at the
// end of this file, as in chapters 17 and 18. The rest is board.v as it is:
// one cycle of the processor every two ticks of the pixel clock, the six pins
// of the LEDs upside down (an LED is lit when its pin is LOW), button S2 on
// NMI, button S1 the reset, and now the two pins of the serial link, where
// the Mac of mac.v sends maze.s, as in computer_tb, through the flip-flop on
// pin 70, and hears every line come back on pin 69.
// When maze.s has begun, S2 bounces: several NMIs, and the maze must be drawn
// without waiting. Then S1 must start everything again: the LEDs back to 0,
// the colors painted again, and load.s listening again.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire       uart_rx;
    wire       uart_tx;
    reg        go   = 0;
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
        .led        (led),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n),
        .tmds_d_p   (tmds_d_p),
        .tmds_d_n   (tmds_d_n)
    );

    mac the_mac (
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
    reg [5:0] pins_before   = 6'b111111;
    integer  drawn_at  = 0;     // the tick at which the last cell of the maze is drawn
    integer  listens   = 0;     // the times load.s begins to listen
    reg      maze_begun = 0;

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
            $display("tick %8d: the pins show %b, the LEDs show %2d", ticks, led, ~led);
            pins_before = led;
        end
        if (dut.step && ~dut.reset) begin
            if (address == 16'hFFFA && ~write) nmis = nmis + 1;
            if (address == 16'h9C00 && write) begin
                painted = painted + 1;
                $display("tick %8d: the colors are painted (a write at $9C00)", ticks);
            end
            // load.s begins to listen: the first read of $8011 after the colors.
            if (address == 16'h8011 && ~write && listens < painted) begin
                listens = listens + 1;
                $display("tick %8d: load.s listens", ticks);
                go = 1;
            end
            if (maze_begun && address == 16'hBF3F && write && drawn_at == 0) drawn_at = ticks;
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

    integer nmis_before;
    integer painted_before;
    reg [5:0] held;

    initial begin
        // The Mac sends maze.s; then maze.s begins: the LEDs show 1.
        wait (done);
        $display("tick %8d: the Mac has sent %0d lines through the pins; %0d characters came back different, %0d lines late",
                 ticks, the_mac.lines, the_mac.wrong, the_mac.late);
        if (the_mac.wrong != 0 || the_mac.late != 0) errors = errors + 1;
        wait (~led == 6'd1);
        maze_begun = 1;
        // S2, with a bounce of 400 ticks.
        #(1000 * 40);
        $display("tick %8d: S2 pressed, with a bounce of 400 ticks", ticks);
        bouncing(1, 400);
        #(2000 * 40);
        bouncing(0, 400);
        $display("tick %8d: S2 let go; %0d NMIs", ticks, nmis);
        if (nmis < 2) begin
            $display("wrong: a bouncing button should make several NMIs at this speed");
            errors = errors + 1;
        end

        // Without waiting, the maze takes less than a million ticks; with the
        // waits, more than 60 million.
        wait (drawn_at != 0 || ticks > 9_000_000);
        if (drawn_at == 0) begin
            $display("wrong: the maze is not drawn after %0d ticks", ticks);
            errors = errors + 1;
        end else begin
            $display("tick %8d: the last cell of the maze is drawn", drawn_at);
        end

        // S1 held: everything freezes. Let go: load.s again.
        #(100 * 40);
        btn1 = 1;
        $display("tick %8d: S1 held", ticks);
        held = led;
        #(20000 * 40);
        if (led !== held) begin
            $display("wrong: the pins moved while S1 was held");
            errors = errors + 1;
        end
        painted_before = painted;
        btn1 = 0;
        $display("tick %8d: S1 let go", ticks);
        wait (listens == 2 || ticks > 9_900_000);
        if (led !== 6'b111111) begin
            $display("wrong: after S1 the pins show %b, expected 111111", led);
            errors = errors + 1;
        end
        if (painted == painted_before) begin
            $display("wrong: after S1 the colors are not painted again");
            errors = errors + 1;
        end
        if (listens != 2) begin
            $display("wrong: after S1 load.s does not listen again");
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
            $display("PASS: board, one cycle every two ticks of the pixel clock; maze.s sent through pins 70 and 69, every line back; S2 with its bounces: the maze drawn without waiting by tick %0d; S1 starts everything again",
                     drawn_at);
            $finish;
        end else begin
            $display("FAIL: board, %0d error(s)", errors);
            $fatal;
        end
    end

    // A limit, as in every test bench of a processor.
    initial begin
        #(10_000_000 * 40);
        $display("FAIL: board, still running after 10 million ticks");
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
