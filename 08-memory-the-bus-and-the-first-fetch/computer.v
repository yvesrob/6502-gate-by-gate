// Chapter 8: our computer, so far. A processor, a ROM that holds its program,
// a RAM, and the bus that ties them together.
//
//   $0000-$7FFF   the RAM: 32,768 bytes
//   $8000-$BFFF   nothing yet
//   $C000-$FFFF   the ROM: 16,384 bytes
module computer (
    input  wire        clk,
    input  wire        reset,       // 1: the processor starts again
    input  wire        step,        // 1: the processor does one cycle at the next tick
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

    // Who is the processor talking to? The top bits of the address say it.
    wire ram_selected;
    wire rom_selected;
    assign ram_selected = (address[15] == 1'b0);        // $0000-$7FFF
    assign rom_selected = (address[15:14] == 2'b11);    // $C000-$FFFF

    // Both memories see the low bits of every address, and both answer. They
    // do not know whether they were meant.
    wire [7:0] ram_data;
    wire [7:0] rom_data;

    ram the_ram (
        .clk      (clk),
        .address  (address[14:0]),
        .write    (write & ram_selected),   // only the RAM can be written
        .data_in  (data_out),
        .data_out (ram_data)
    );

    rom #(.FILE(PROGRAM)) the_rom (
        .clk     (clk),
        .address (address[13:0]),
        .data    (rom_data)
    );

    // The processor gets the answer of the one it was talking to. Where
    // there is no memory, it reads zero.
    assign data_in = ram_selected ? ram_data :
                     rom_selected ? rom_data : 8'h00;
endmodule
