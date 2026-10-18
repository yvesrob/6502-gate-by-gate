// Chapter 21: a queue of bytes. Bytes go in at one end, when they arrive,
// and leave at the other, when the processor takes them, in the order they
// came: first in, first out. It is a memory of 256 bytes and two counters.
// in says where the next byte goes; out says where the first one waits.
// Each counter goes up by one, and after 255 comes 0 again, by itself: a
// byte of eight bits does that. So the 256 places make a ring.
//
// When in and out are the same, the queue is empty. When in is just behind
// out, it is full: 255 bytes wait, and a byte that comes then is lost. One
// place always stays empty, so that full and empty look different.
module queue (
    input  wire       clk,
    input  wire       put,              // 1 during one tick: data goes in at the end
    input  wire [7:0] data,
    input  wire       take,             // 1 during one tick: the first byte leaves
    output reg  [7:0] first,            // the first byte, one tick after it changes
    output wire       ready             // 1: at least one byte waits
);
    reg [7:0] bytes [0:255];
    reg [7:0] in  = 0;                  // where the next byte goes
    reg [7:0] out = 0;                  // where the first byte waits

    always @(posedge clk) begin
        if (put && in + 8'd1 != out) begin
            bytes[in] <= data;
            in <= in + 1;
        end
        if (take && ready) begin
            out <= out + 1;
        end
        first <= bytes[out];
    end

    assign ready = (in != out);
endmodule
