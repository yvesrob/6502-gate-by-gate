// Chapter 23 uses the transmitter from chapter 19. This file is a copy of it, unchanged.
// Chapter 19: the transmitter of the serial link, the receiver's twin. It
// sends a byte to the Mac as ten bits on one wire: a start bit at 0, the
// eight bits of the byte, the lowest first, and a stop bit at 1. Each bit
// stays on the wire for 219 ticks of the 25.2 MHz clock: 115,068 bits a
// second, which the Mac takes for 115,200. Between two bytes the wire
// rests at 1.
//
// send at 1 during one tick starts a byte. busy is 1 until its stop bit is
// over: ten bits, 2,190 ticks, 86.9 microseconds. A byte sent while busy is
// 1 is lost.
module transmitter (
    input  wire       clk,
    input  wire       send,             // 1 during one tick: send data
    input  wire [7:0] data,             // the byte to send
    output wire       tx,               // the wire to the Mac
    output wire       busy              // 1 while a byte is going out
);
    parameter TICKS = 219;              // ticks of the clock for one bit, as in the receiver

    reg [9:0] bits  = 10'b1111111111;   // the bits still to go out; the one on the wire is bit 0
    reg [3:0] left  = 0;                // how many of them: 0 when nothing is going out
    reg [7:0] count = 0;                // ticks before the next bit

    always @(posedge clk) begin
        if (left == 0) begin
            if (send) begin
                // The stop bit, the byte, and the start bit, which goes first.
                bits  <= {1'b1, data, 1'b0};
                left  <= 10;
                count <= TICKS - 1;
            end
        end else if (count != 0) begin
            count <= count - 1;
        end else begin
            // A bit has lasted long enough: the next one. A 1 comes in at the
            // top, so that the wire rests at 1 after the stop bit.
            bits  <= {1'b1, bits[9:1]};
            left  <= left - 1;
            count <= TICKS - 1;
        end
    end

    assign tx   = bits[0];
    assign busy = (left != 0);
endmodule
