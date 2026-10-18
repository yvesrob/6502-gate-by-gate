// Chapter 17: the computer from chapter 15, with the picture in its memory.
// The bitmap and the colors from chapter 6 are now two memories that the
// processor reads and writes like its RAM, at addresses of their own. Each
// has a second door, through which the display reads at the same time;
// that door comes out of the computer, to the display.
//
//   $0000-$7FFF   the RAM: 32,768 bytes
//   $8000         the six LEDs
//   $8001-$9BFF   nothing yet
//   $9C00-$9FFF   the colors: 1,024 bytes. The display shows the first
//                 1,000, one for each cell of 8 x 8 pixels
//   $A000-$BFFF   the bitmap: 8,192 bytes. The display shows the first
//                 8,000, one bit for each pixel
//   $C000-$FFFF   the ROM: 16,384 bytes
module computer (
    input  wire        clk,
    input  wire        reset,       // 1: the processor starts again
    input  wire        step,        // 1: the processor does one cycle at the next tick
    input  wire        irq,         // 1: a device asks for attention (the flag I can refuse it)
    input  wire        nmi,         // from 0 to 1: a device asks, and it cannot be refused
    output reg  [5:0]  leds = 0,    // the last byte stored at $8000: its six low bits
    // The bus comes out of the computer, so that we can watch it.
    output wire [15:0] address,     // which byte the processor wants
    output wire [7:0]  data_in,     // what it reads (in and out are the processor's)
    output wire [7:0]  data_out,    // what it writes
    output wire        write,       // 1: it is writing
    // The display's door into the picture: an address in, a byte out, one
    // tick later.
    input  wire [12:0] bitmap_address,
    output wire [7:0]  bitmap_byte,
    input  wire [9:0]  colors_address,
    output wire [7:0]  colors_byte
);
    // The file that fills the ROM.
    parameter PROGRAM = "rom.hex";

    cpu processor (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .irq      (irq),
        .nmi      (nmi),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // Who is the processor talking to? The address says it.
    wire ram_selected;
    wire rom_selected;
    wire leds_selected;
    wire colors_selected;
    wire bitmap_selected;
    assign ram_selected    = (address[15] == 1'b0);          // $0000-$7FFF
    assign rom_selected    = (address[15:14] == 2'b11);      // $C000-$FFFF
    assign leds_selected   = (address == 16'h8000);          // one address, all sixteen bits
    assign colors_selected = (address[15:10] == 6'b100111);  // $9C00-$9FFF
    assign bitmap_selected = (address[15:13] == 3'b101);     // $A000-$BFFF

    // All four memories see the low bits of every address, and all four
    // answer. They do not know whether they were meant.
    wire [7:0] ram_data;
    wire [7:0] rom_data;
    wire [7:0] colors_data;
    wire [7:0] bitmap_data;

    ram the_ram (
        .clk      (clk),
        .address  (address[14:0]),
        .write    (write & ram_selected),   // only what is meant for the RAM
        .data_in  (data_out),
        .data_out (ram_data)
    );

    rom #(.FILE(PROGRAM)) the_rom (
        .clk     (clk),
        .address (address[13:0]),
        .data    (rom_data)
    );

    // The two memories of the picture. The processor's door works like the
    // RAM's; the display's door only reads.
    picture_ram #(.WORDS(1024)) the_colors (
        .clk             (clk),
        .address         ({3'b000, address[9:0]}),    // 10 bits are enough
        .write           (write & colors_selected),
        .data_in         (data_out),
        .data_out        (colors_data),
        .display_address ({3'b000, colors_address}),
        .display_data    (colors_byte)
    );

    picture_ram #(.WORDS(8192)) the_bitmap (
        .clk             (clk),
        .address         (address[12:0]),
        .write           (write & bitmap_selected),
        .data_in         (data_out),
        .data_out        (bitmap_data),
        .display_address (bitmap_address),
        .display_data    (bitmap_byte)
    );

    // The LEDs: a register of six bits that sits on the bus like a cell of
    // memory. A byte written at $8000 lands here, and stays.
    always @(posedge clk) begin
        if (write & leds_selected) begin
            leds <= data_out[5:0];
        end
    end

    // The processor gets the answer of the one it was talking to. The LEDs
    // can be read back too. Where there is nothing, it reads zero.
    assign data_in = ram_selected    ? ram_data      :
                     rom_selected    ? rom_data      :
                     leds_selected   ? {2'b00, leds} :
                     colors_selected ? colors_data   :
                     bitmap_selected ? bitmap_data   : 8'h00;
endmodule
