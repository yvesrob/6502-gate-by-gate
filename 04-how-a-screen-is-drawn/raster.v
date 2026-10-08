// Chapter 4: the raster. Two counters that sweep the picture, left to right
// and top to bottom, sixty times a second: 640 x 480 pixels at 60 Hz.
module raster (
    input  wire       clk,          // the pixel clock: one tick, one pixel
    output reg  [9:0] x = 0,        // where we are on the line: 0 to 799
    output reg  [9:0] y = 0,        // which line we are on: 0 to 524
    output wire       hsync,        // LOW during the pulse that ends a line
    output wire       vsync,        // LOW during the pulse that ends a frame
    output wire       visible       // 1 while (x, y) is inside the picture
);
    // One line, counted in pixels: the picture, then three stretches
    // that the screen does not show.
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;      // the front porch: a short wait
    localparam H_SYNC    = 96;      // the sync pulse
    localparam H_BACK    = 48;      // the back porch: another wait
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;    // 800

    // One frame, counted in lines: the same four stretches, top to bottom.
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;    // 525

    // Where the two pulses begin and end.
    localparam H_SYNC_START = H_VISIBLE + H_FRONT;                   // 656
    localparam H_SYNC_END   = H_SYNC_START + H_SYNC;                 // 752
    localparam V_SYNC_START = V_VISIBLE + V_FRONT;                   // 490
    localparam V_SYNC_END   = V_SYNC_START + V_SYNC;                 // 492

    // x counts the pixels of a line. Each time it starts again, y counts one more line.
    always @(posedge clk) begin
        if (x == H_TOTAL - 1) begin
            x <= 0;
            if (y == V_TOTAL - 1) begin
                y <= 0;
            end else begin
                y <= y + 1;
            end
        end else begin
            x <= x + 1;
        end
    end

    // The three outputs are comparisons: they only look at where x and y are.
    assign visible = (x < H_VISIBLE) & (y < V_VISIBLE);

    // Both pulses are active LOW: the wire rests at 1 and drops to 0 during the pulse.
    assign hsync = ~((x >= H_SYNC_START) & (x < H_SYNC_END));
    assign vsync = ~((y >= V_SYNC_START) & (y < V_SYNC_END));
endmodule
