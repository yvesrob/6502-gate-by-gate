// Chapter 5: the serializer. It takes the ten bits of a code, all at once,
// and sends them out one after the other on a single wire, bit 0 first.
module serializer (
    input  wire       pixel_clk,    // one tick, one code of ten bits
    input  wire       fast_clk,     // five ticks for each code
    input  wire       reset,        // 1: wait
    input  wire [9:0] code,
    output wire       serial        // the ten bits, one after the other
);
    // OSER10 is a part of the chip, like the PLL: a ten-bit serializer that
    // sits right next to a pin. It sends one bit on each edge of the fast
    // clock, the rising one and the falling one: ten bits in five ticks.
    OSER10 ten_to_one (
        .PCLK  (pixel_clk),
        .FCLK  (fast_clk),
        .RESET (reset),
        .D0    (code[0]),
        .D1    (code[1]),
        .D2    (code[2]),
        .D3    (code[3]),
        .D4    (code[4]),
        .D5    (code[5]),
        .D6    (code[6]),
        .D7    (code[7]),
        .D8    (code[8]),
        .D9    (code[9]),
        .Q     (serial)
    );
endmodule
