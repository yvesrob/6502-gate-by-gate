// Chapter 19: the receiver of the serial link. The Mac sends a byte as ten
// bits, one after the other, on a single wire, each bit held for the same
// time: at 115,200 bits a second, 8.68 microseconds. When nothing is sent,
// the wire rests at 1. A byte begins with a start bit at 0, then come its
// eight bits, the lowest first, then a stop bit at 1.
//
// No clock comes with the bits: the receiver keeps time itself. When the
// wire falls to 0, it waits half a bit, to the middle of the start bit, and
// looks again: still 0, it is a start bit. Then it looks once a bit, in the
// middle of each one, where the wire is surest.
//
// When the stop bit is there, the byte is out on data, and arrived is 1
// during one tick. A byte without its stop bit is thrown away.
module receiver (
    input  wire       clk,
    input  wire       rx,               // the wire from the Mac: 1 when nothing comes
    output reg  [7:0] data    = 0,      // the last byte that arrived
    output reg        arrived = 0       // 1 during one tick: a byte has just arrived
);
    // Ticks of the clock for one bit. At 25.2 MHz and 115,200 bits a second
    // a bit lasts 218.75 ticks; we count 219, so we read 115,068 bits a
    // second, 0.11 % slow. Over the ten bits of a byte we drift by less than
    // three ticks: the middle of the stop bit is still far from its edges.
    parameter TICKS = 219;

    reg [7:0] count = 0;    // ticks to wait before the middle of the next bit
    reg [3:0] which = 0;    // which bit comes next: 0, none, we wait for a byte;
                            // 1, the start bit; 2 to 9, the eight bits; 10, the stop bit
    reg [7:0] bits  = 0;    // the eight bits so far

    always @(posedge clk) begin
        arrived <= 0;
        if (which == 0) begin
            if (rx == 0) begin
                // The wire falls: a start bit begins. Its middle is half a
                // bit away.
                which <= 1;
                count <= TICKS / 2;
            end
        end else if (count != 0) begin
            count <= count - 1;
        end else begin
            // The middle of a bit: look at the wire. The middle of the next
            // bit is one whole bit away.
            count <= TICKS - 1;
            if (which == 1) begin
                // Still 0: a start bit. Back at 1: it was only a glitch.
                which <= (rx == 0) ? 2 : 0;
            end else if (which <= 9) begin
                // One of the eight bits. The lowest comes first: each bit
                // goes in at the top, and the ones before move down.
                bits  <= {rx, bits[7:1]};
                which <= which + 1;
            end else begin
                // The stop bit. At 1, the byte is good; at 0, it is not.
                if (rx == 1) begin
                    data    <= bits;
                    arrived <= 1;
                end
                which <= 0;
            end
        end
    end
endmodule
