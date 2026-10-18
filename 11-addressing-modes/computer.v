// Chapter 11 uses the computer from chapter 10. This file is a copy of it, unchanged.
// Chapter 10: our computer. A processor, a ROM that holds its program, a RAM,
// the bus that ties them together, and a first way out: six LEDs.
//
//   $0000-$7FFF   the RAM: 32,768 bytes
//   $8000         the six LEDs
//   $8001-$BFFF   nothing yet
//   $C000-$FFFF   the ROM: 16,384 bytes
module computer (
    input  wire        clk,
    input  wire        reset,       // 1: the processor starts again
    input  wire        step,        // 1: the processor does one cycle at the next tick
    output reg  [5:0]  leds = 0,    // the last byte stored at $8000: its six low bits
    // The bus comes out of the computer, so that we can watch it.
    output wire [15:0] address,     // which byte the processor wants
    output wire [7:0]  data_in,     // what it reads (in and out are the processor's)
    output wire [7:0]  data_out,    // what it writes
    output wire        write        // 1: it is writing
);
    // The file that fills the ROM.
    parameter PROGRAM = "rom.hex";

    cpu processor (
        .clk      (clk),
        .reset    (reset),
        .step     (step),
        .address  (address),
        .data_in  (data_in),
        .data_out (data_out),
        .write    (write)
    );

    // Who is the processor talking to? The address says it.
    wire ram_selected;
    wire rom_selected;
    wire leds_selected;
    assign ram_selected  = (address[15] == 1'b0);       // $0000-$7FFF
    assign rom_selected  = (address[15:14] == 2'b11);   // $C000-$FFFF
    assign leds_selected = (address == 16'h8000);       // one address, all sixteen bits

    // Both memories see the low bits of every address, and both answer. They
    // do not know whether they were meant.
    wire [7:0] ram_data;
    wire [7:0] rom_data;

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

    // The LEDs: a register of six bits that sits on the bus like a cell of
    // memory. A byte written at $8000 lands here, and stays.
    always @(posedge clk) begin
        if (write & leds_selected) begin
            leds <= data_out[5:0];
        end
    end

    // The processor gets the answer of the one it was talking to. The LEDs
    // can be read back too. Where there is nothing, it reads zero.
    assign data_in = ram_selected  ? ram_data      :
                     rom_selected  ? rom_data      :
                     leds_selected ? {2'b00, leds} : 8'h00;
endmodule
