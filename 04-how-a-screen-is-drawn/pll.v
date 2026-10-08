// Chapter 4: the pixel clock. The crystal of the board gives 27 MHz and the
// screen wants 25.2 MHz. No counter can make one from the other. A PLL can:
// it is a part of the chip that multiplies and divides the frequency of a clock.
module pll (
    input  wire clk,            // the board's 27 MHz clock
    output wire pixel_clk       // 25.2 MHz: one tick, one pixel
);
    wire fast_clk;              // 126 MHz: five ticks for each pixel
    wire locked;                // 1 once the PLL has settled on its frequency

    // First step: 27 MHz, divided by 3 and multiplied by 14, gives 126 MHz.
    // rPLL is not a module of ours. It is a part that already exists in the
    // chip, like the flip-flop. Its settings come from a tool of the suite:
    //     gowin_pll -d "GW2AR-18 C8/I7" -i 27 -o 126
    rPLL #(
        .FCLKIN    ("27"),      // the frequency that comes in, in MHz
        .IDIV_SEL  (2),         // divide by 3: the setting is the divider minus one
        .FBDIV_SEL (13),        // multiply by 14: same rule
        .ODIV_SEL  (4)          // keeps the PLL's own oscillator in its range (504 MHz)
    ) multiply (
        .CLKIN    (clk),
        .CLKOUT   (fast_clk),
        .LOCK     (locked),
        // The inputs we do not use are tied to 0...
        .RESET    (1'b0),
        .RESET_P  (1'b0),
        .CLKFB    (1'b0),
        .FBDSEL   (6'b000000),
        .IDSEL    (6'b000000),
        .ODSEL    (6'b000000),
        .PSDA     (4'b0000),
        .DUTYDA   (4'b0000),
        .FDLY     (4'b0000),
        // ...and the outputs we do not use are left unconnected.
        .CLKOUTP  (),
        .CLKOUTD  (),
        .CLKOUTD3 ()
    );

    // Second step: 126 MHz divided by 5 gives 25.2 MHz.
    // CLKDIV is another part of the chip, made to divide a fast clock.
    CLKDIV #(
        .DIV_MODE ("5")
    ) divide (
        .HCLKIN (fast_clk),
        .RESETN (locked),       // held at rest until the PLL has settled
        .CALIB  (1'b0),
        .CLKOUT (pixel_clk)
    );
endmodule
