// Chapter 21, test bench for board.v: what goes onto the board, pins and all.
// The PLL, the serializers and the pairs of pins are parts of the chip that
// the simulator does not know. The test bench gives it four stand-ins, at the
// end of this file, as in chapters 17 to 19. The rest is board.v as it is:
// one cycle of the processor every two ticks of the pixel clock, the six pins
// of the LEDs upside down (an LED is lit when its pin is LOW), button S2 on
// NMI, button S1 the reset, the serial link to the Mac on pins 70 and 69, and
// now pin 42, where the keyboard's module of ch9350.v sends its frames,
// through the flip-flop. The module plays its shorter story (QUICK): it
// starts, Q, W and E are typed, a mouse moves, and bytes that begin no frame
// come before the space bar.
// While Q, W and E are typed, S2 bounces: several NMIs, which keys.s answers
// with nothing. At the end, the Mac must have heard every line, and the
// LEDs must be off. Then S1 must start everything again: the colors painted
// again, the title sent to the Mac again, and keys.s listening again.
`timescale 1ns/1ns
module board_tb;
    reg        clk  = 0;
    reg        btn1 = 0;
    reg        btn2 = 0;
    wire       uart_tx;
    wire       keyboard_rx;
    reg        go   = 0;
    wire       done;
    wire [3:0] phase;
    wire [5:0] led;
    wire       tmds_clk_p;
    wire       tmds_clk_n;
    wire [2:0] tmds_d_p;
    wire [2:0] tmds_d_n;

    top dut (
        .clk         (clk),
        .btn1        (btn1),
        .btn2        (btn2),
        .uart_rx     (1'b1),        // the Mac sends nothing
        .uart_tx     (uart_tx),
        .keyboard_rx (keyboard_rx),
        .led         (led),
        .tmds_clk_p  (tmds_clk_p),
        .tmds_clk_n  (tmds_clk_n),
        .tmds_d_p    (tmds_d_p),
        .tmds_d_n    (tmds_d_n)
    );

    ch9350 #(.QUICK(1)) module_and_keyboard (
        .go    (go),
        .tx    (keyboard_rx),
        .done  (done),
        .phase (phase)
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

    // The Mac listens on pin 69, as in computer_tb.
    localparam BIT = 8760;
    reg [7:0] heard [0:8191];
    integer   count  = 0;
    integer   broken = 0;
    reg [7:0] byte_heard;
    integer   k;
    initial begin
        forever begin
            @(negedge uart_tx);
            #(BIT / 2);
            if (uart_tx == 0) begin
                for (k = 0; k < 8; k = k + 1) begin
                    #(BIT);
                    byte_heard[k] = uart_tx;
                end
                #(BIT);
                if (uart_tx !== 1) broken = broken + 1;
                heard[count] = byte_heard;
                count = count + 1;
            end
        end
    end

    // The text the Mac should hear: the title, then a line for each report
    // that differs from the one before, and the line about the bytes skipped.
    reg [7:0] text [0:8191];
    integer   length = 0;

    task put;
        input integer code;
        begin
            text[length] = code;
            length = length + 1;
        end
    endtask

    task put_text;
        input [8 * 40 - 1:0] words;
        integer j;
        begin
            for (j = 39; j >= 0; j = j - 1) begin
                if (words[8 * j +: 8] != 0) put(words[8 * j +: 8]);
            end
        end
    endtask

    task put_digit;
        input [3:0] value;
        begin
            if (value < 10) put("0" + value);
            else put("A" + value - 10);
        end
    endtask

    task put_title;
        begin
            put_text("Our Own 6502, Gate by Gate");
            put(13);
            put(10);
            put_text("Chapter 21: A Real USB Keyboard");
            put(13);
            put(10);
            put(13);
            put(10);
            put_text("Keyboard reports, when they change:");
            put(13);
            put(10);
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
    integer listens    = 0;     // the times keys.s begins to listen
    integer polls      = 0;     // reads of $8021 since the last byte taken
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
            $display("tick %8d: the pins show %b, the LEDs show %2d", ticks, led, ~led);
            pins_before = led;
        end
        if (dut.step && ~dut.reset) begin
            if (address == 16'hFFFA && ~write) nmis = nmis + 1;
            if (address == 16'h9C00 && write) begin
                painted = painted + 1;
                $display("tick %8d: the colors are painted (a write at $9C00)", ticks);
            end
            if (address == 16'h8020 && ~write) polls = 0;
            if (address == 16'h8021 && ~write) polls = polls + 1;
            // keys.s begins to listen: the first read of $8021 after the colors.
            if (address == 16'h8021 && ~write && listens < painted) begin
                listens = listens + 1;
                $display("tick %8d: keys.s listens", ticks);
                go = 1;
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

    integer    painted_before;
    integer    heard_before;
    integer    j, wrong_text, lines, said;
    reg [63:0] last;
    reg [5:0]  held;

    initial begin
        put_title;

        // While W is typed: S2, with a bounce of 400 ticks.
        wait (module_and_keyboard.reports == 8);
        $display("tick %8d: S2 pressed, with a bounce of 400 ticks", ticks);
        bouncing(1, 400);
        #(2000 * 40);
        bouncing(0, 400);
        $display("tick %8d: S2 let go; %0d NMIs", ticks, nmis);
        if (nmis < 2) begin
            $display("wrong: a bouncing button should make several NMIs at this speed");
            errors = errors + 1;
        end

        // Everything sent, everything taken, and keys.s waiting again.
        wait (done && !dut.our_computer.queued && polls > 2000);
        last  = 64'h0;
        lines = 0;
        said  = 0;
        for (j = 0; j < module_and_keyboard.reports; j = j + 1) begin
            if (module_and_keyboard.skipped[j] != said) begin
                said = module_and_keyboard.skipped[j];
                put_text("Bytes skipped: ");
                put_digit(said[7:4]);
                put_digit(said[3:0]);
                put(13);
                put(10);
            end
            if (module_and_keyboard.sent[j] !== last) begin
                last = module_and_keyboard.sent[j];
                for (k = 7; k >= 0; k = k - 1) begin
                    put_digit(last[8 * k + 4 +: 4]);
                    put_digit(last[8 * k +: 4]);
                    if (k != 0) put(" ");
                end
                put(13);
                put(10);
                lines = lines + 1;
            end
        end
        wrong_text = 0;
        for (j = 0; j < length; j = j + 1) begin
            if (j >= count || heard[j] !== text[j]) wrong_text = wrong_text + 1;
        end
        $display("tick %8d: the module has sent %0d bytes through pin 42; the Mac heard %0d bytes on pin 69, %0d expected (the title and %0d lines), %0d different",
                 ticks, module_and_keyboard.bytes, count, length, lines, wrong_text);
        if (count != length || wrong_text != 0) errors = errors + 1;
        if (led !== 6'b111111) begin
            $display("wrong: at the end the pins show %b, expected 111111", led);
            errors = errors + 1;
        end

        // S1 held: everything freezes. Let go: keys.s again.
        #(100 * 40);
        btn1 = 1;
        $display("tick %8d: S1 held", ticks);
        held = led;
        heard_before = count;
        #(20000 * 40);
        if (led !== held) begin
            $display("wrong: the pins moved while S1 was held");
            errors = errors + 1;
        end
        painted_before = painted;
        btn1 = 0;
        $display("tick %8d: S1 let go", ticks);
        wait (listens == 2 || ticks > 19_900_000);
        #(3000 * 40);                       // the last byte of the title is still going out
        put_title;
        wrong_text = 0;
        for (j = 0; j < 100; j = j + 1) begin
            if (heard[heard_before + j] !== text[length - 100 + j]) wrong_text = wrong_text + 1;
        end
        $display("tick %8d: after S1 the Mac heard %0d bytes, the title is %0d; %0d different", ticks,
                 count - heard_before, 100, wrong_text);
        if (count - heard_before != 100 || wrong_text != 0) errors = errors + 1;
        if (led !== 6'b111111) begin
            $display("wrong: after S1 the pins show %b, expected 111111", led);
            errors = errors + 1;
        end
        if (painted == painted_before) begin
            $display("wrong: after S1 the colors are not painted again");
            errors = errors + 1;
        end
        if (listens != 2) begin
            $display("wrong: after S1 keys.s does not listen again");
            errors = errors + 1;
        end
        if (gaps != 0) begin
            $display("wrong: %0d steps did not come two ticks after the one before", gaps);
            errors = errors + 1;
        end
        if (broken != 0) begin
            $display("wrong: the Mac heard %0d bytes without their stop bit", broken);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: board, one cycle every two ticks of the pixel clock; the keyboard's frames through pin 42, every line to the Mac through pin 69; S2 with its bounces changes nothing; S1 starts everything again");
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
