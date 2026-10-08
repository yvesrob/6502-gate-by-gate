// Chapter 3: a first state machine. One light runs along the six LEDs,
// turns around at the end, and runs back.
module scanner (
    input  wire       clk,
    input  wire       step,                 // 1: move at the next tick
    output reg  [5:0] light = 6'b000001     // one bit per LED, a single 1 among them
);
    // The two states this machine can be in. A localparam is a parameter
    // that nobody can change from outside.
    localparam GOING_UP   = 0;
    localparam GOING_DOWN = 1;

    // The state is what the machine remembers: which way it is going.
    reg state = GOING_UP;

    always @(posedge clk) begin
        if (step) begin
            case (state)
                GOING_UP: begin
                    if (light[5]) begin
                        // At the top: turn around, and take the first step down.
                        state <= GOING_DOWN;
                        light <= light >> 1;
                    end else begin
                        light <= light << 1;
                    end
                end
                GOING_DOWN: begin
                    if (light[0]) begin
                        // At the bottom: turn around, and take the first step up.
                        state <= GOING_UP;
                        light <= light << 1;
                    end else begin
                        light <= light >> 1;
                    end
                end
            endcase
        end
    end
endmodule
