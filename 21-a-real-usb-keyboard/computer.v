// Chapter 21: the computer from chapter 19, with a keyboard. A USB keyboard
// is plugged into a module whose chip, the CH9350, sends what the keyboard
// says on a wire of its own, as the Mac does: a second receiver, and a queue
// where its bytes wait for the processor. The rest is chapter 19's.
//
//   $0000-$7FFF   the RAM: 32,768 bytes
//   $8000         the six LEDs
//   $8010         the serial link: read, the byte that has arrived; write,
//                 a byte to send
//   $8011         the state of the link: bit 7 at 1, a byte has arrived and
//                 waits to be read; bit 6 at 1, a byte is still going out
//   $8020         the keyboard: read, the first byte in the queue; reading
//                 takes it
//   $8021         the state of the queue: bit 7 at 1, at least one byte waits
//   $9C00-$9FFF   the colors: 1,024 bytes. The display shows the first
//                 1,000, one for each cell of 8 x 8 pixels
//   $A000-$BFFF   the bitmap: 8,192 bytes. The display shows the first
//                 8,000, one bit for each pixel
//   $C000-$FFFF   the ROM: 16,384 bytes
//   Elsewhere there is nothing yet.
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
    output wire [7:0]  colors_byte,
    // Chapter 19: the two wires of the serial link.
    input  wire        rx,          // from the Mac: 1 when nothing comes
    output wire        tx,          // to the Mac
    // Chapter 21: the wire from the keyboard's module.
    input  wire        keyboard     // 1 when nothing comes
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
    wire serial_selected;
    wire status_selected;
    wire keyboard_selected;
    wire queue_selected;
    assign ram_selected    = (address[15] == 1'b0);          // $0000-$7FFF
    assign rom_selected    = (address[15:14] == 2'b11);      // $C000-$FFFF
    assign leds_selected   = (address == 16'h8000);          // one address, all sixteen bits
    assign colors_selected = (address[15:10] == 6'b100111);  // $9C00-$9FFF
    assign bitmap_selected = (address[15:13] == 3'b101);     // $A000-$BFFF
    assign serial_selected = (address == 16'h8010);          // one address each, like the LEDs
    assign status_selected = (address == 16'h8011);
    assign keyboard_selected = (address == 16'h8020);
    assign queue_selected    = (address == 16'h8021);

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

    // Chapter 19: the serial link. Reading $8010 and writing it do something:
    // a byte goes out, or the byte that waited is taken. A cycle lasts at
    // least two ticks, and the address stays on the bus all the while, so the
    // port acts only at the tick when step is 1: the step that ends the cycle.
    // At that tick the bus still shows the cycle that ends, and the
    // processor takes the byte it reads. Once a cycle, at any speed.
    wire [7:0] received;
    wire       arrived;
    wire       sending;

    receiver from_the_mac (
        .clk     (clk),
        .rx      (rx),
        .data    (received),
        .arrived (arrived)
    );

    transmitter to_the_mac (
        .clk  (clk),
        .send (step & write & serial_selected),     // the processor stores at $8010
        .data (data_out),
        .tx   (tx),
        .busy (sending)
    );

    // A byte has arrived, and the processor has not read it yet. Reading
    // $8010 takes it. If arrived comes at the very tick of a read, it wins:
    // the byte read is the new one, and it waits to be read a second time.
    reg waiting = 0;

    always @(posedge clk) begin
        if (arrived) begin
            waiting <= 1;
        end else if (step & ~write & serial_selected) begin
            waiting <= 0;
        end
    end

    // Chapter 21: the keyboard. Its module sends at 115,200 bits a second,
    // like the Mac: the same receiver hears it. But it sends eleven bytes at
    // a time, and the processor is sometimes busy for longer than a byte
    // takes to come: while the screen scrolls, 10 milliseconds, more than a
    // hundred bytes could come. So they wait in a queue. Reading $8020 takes
    // the first, at the step that ends the cycle, as for $8010.
    wire [7:0] from_keyboard;
    wire       keyboard_arrived;
    wire [7:0] first_in_line;
    wire       queued;

    receiver from_the_keyboard (
        .clk     (clk),
        .rx      (keyboard),
        .data    (from_keyboard),
        .arrived (keyboard_arrived)
    );

    queue keyboard_queue (
        .clk   (clk),
        .put   (keyboard_arrived),
        .data  (from_keyboard),
        .take  (step & ~write & keyboard_selected),   // the processor reads $8020
        .first (first_in_line),
        .ready (queued)
    );

    // The processor gets the answer of the one it was talking to. The LEDs
    // can be read back too. Where there is nothing, it reads zero.
    assign data_in = ram_selected      ? ram_data                      :
                     rom_selected      ? rom_data                      :
                     leds_selected     ? {2'b00, leds}                 :
                     serial_selected   ? received                      :
                     status_selected   ? {waiting, sending, 6'b000000} :
                     keyboard_selected ? first_in_line                 :
                     queue_selected    ? {queued, 7'b0000000}          :
                     colors_selected   ? colors_data                   :
                     bitmap_selected   ? bitmap_data                   : 8'h00;
endmodule
