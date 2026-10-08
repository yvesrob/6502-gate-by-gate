// Chapter 6 uses the tmds of chapter 5. This file is a copy of it, unchanged.
// Chapter 5: the TMDS encoder. It turns one byte into the ten bits that
// travel down one pair of wires of the HDMI cable.
module tmds (
    input  wire       clk,          // the pixel clock
    input  wire [7:0] data,         // one color of the pixel: red, green or blue
    input  wire [1:0] control,      // two bits that travel between the pictures
    input  wire       visible,      // 1: send the color. 0: send the control bits
    output reg  [9:0] code = 0      // the ten bits to send, bit 0 first
);
    // Step 1: make the signal change as seldom as possible.
    // Each bit is combined with the one before it, by XOR or by XNOR,
    // whichever gives fewer changes. That depends on how many 1s the byte has.
    wire [3:0] ones;
    assign ones = data[0] + data[1] + data[2] + data[3]
                + data[4] + data[5] + data[6] + data[7];

    wire use_xnor;
    assign use_xnor = (ones > 4) | ((ones == 4) & ~data[0]);

    wire [8:0] chained;
    assign chained[0] = data[0];
    assign chained[1] = chained[0] ^ data[1] ^ use_xnor;
    assign chained[2] = chained[1] ^ data[2] ^ use_xnor;
    assign chained[3] = chained[2] ^ data[3] ^ use_xnor;
    assign chained[4] = chained[3] ^ data[4] ^ use_xnor;
    assign chained[5] = chained[4] ^ data[5] ^ use_xnor;
    assign chained[6] = chained[5] ^ data[6] ^ use_xnor;
    assign chained[7] = chained[6] ^ data[7] ^ use_xnor;
    assign chained[8] = ~use_xnor;  // the ninth bit says which of the two was used

    // Step 2: send as many 1s as 0s, over time.
    // excess says how many more 1s than 0s these eight bits hold: -8 to +8.
    wire [3:0] chained_ones;
    assign chained_ones = chained[0] + chained[1] + chained[2] + chained[3]
                        + chained[4] + chained[5] + chained[6] + chained[7];

    wire signed [4:0] excess;
    assign excess = {1'b0, chained_ones, 1'b0} - 5'sd8;     // twice the 1s, minus 8

    // balance remembers how many more 1s than 0s we have sent so far.
    reg signed [4:0] balance = 0;

    // Sending the eight bits upside down turns their 1s into 0s. We do it
    // when that brings the balance back toward zero.
    wire invert;
    assign invert = ((balance == 0) | (excess == 0)) ? ~chained[8]
                                                     : ((balance > 0) == (excess > 0));

    // What the ten bits we are about to send add to the balance: the eight
    // bits, upside down or not, then the two extra bits, +1 for a 1 and -1 for a 0.
    wire signed [4:0] sent;
    assign sent = (invert ? -excess : excess)
                + (invert     ? 5'sd1 : -5'sd1)
                + (chained[8] ? 5'sd1 : -5'sd1);

    always @(posedge clk) begin
        if (visible) begin
            // The tenth bit says whether the eight bits were inverted.
            code    <= {invert, chained[8], invert ? ~chained[7:0] : chained[7:0]};
            balance <= balance + sent;
        end else begin
            // Between the pictures: four special codes, one for each value of
            // the two control bits, and the balance starts again from zero.
            case (control)
                2'b00: code <= 10'b1101010100;
                2'b01: code <= 10'b0010101011;
                2'b10: code <= 10'b0101010100;
                2'b11: code <= 10'b1010101011;
            endcase
            balance <= 0;
        end
    end
endmodule
