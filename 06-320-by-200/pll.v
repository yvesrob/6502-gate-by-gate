// Chapter 6 uses the pll of chapter 5. This file is a copy of it, unchanged.
// Chapter 5: the two clocks of the picture. This is the pll of chapter 4 with
// two more outputs: the fast clock, which chapter 4 kept to itself, and locked.
module pll (
    input  wire clk,            // the board's 27 MHz clock
    output wire pixel_clk,      // 25.2 MHz: one tick, one pixel
    output wire fast_clk,       // 126 MHz: five ticks for each pixel
    output wire locked          // 1 once the PLL has settled on its frequency
);
    // First step: 27 MHz, divided by 3 and multiplied by 14, gives 126 MHz.
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
    CLKDIV #(
        .DIV_MODE ("5")
    ) divide (
        .HCLKIN (fast_clk),
        .RESETN (locked),       // held at rest until the PLL has settled
        .CALIB  (1'b0),
        .CLKOUT (pixel_clk)
    );
endmodule
