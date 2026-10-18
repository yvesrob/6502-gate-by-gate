// Chapter 22 uses the queue_tb from chapter 21. This file is a copy of it, unchanged.
// Chapter 21, test bench for the queue, alone. A list of its own keeps what
// the queue should hold, in order; after every tick the two must agree.
//   1. 255 bytes go in, one tick apart, and then one more: the queue is full,
//      and the last is lost. They come out in the order they went in.
//   2. 1,000 bytes go in and come out at random moments, sometimes at the
//      same tick, so that the counters go round the ring several times.
//   3. A byte taken when the queue is empty changes nothing.
`timescale 1ns/1ns
module queue_tb;
    reg        clk  = 0;
    reg        put  = 0;
    reg  [7:0] data = 0;
    reg        take = 0;
    wire [7:0] first;
    wire       ready;

    queue the_queue (
        .clk   (clk),
        .put   (put),
        .data  (data),
        .take  (take),
        .first (first),
        .ready (ready)
    );

    always #20 clk = ~clk;

    // The test bench's own list: a ring as long as it needs.
    reg [7:0] list [0:4095];
    integer   head   = 0;       // the first byte of the list
    integer   tail   = 0;       // where the next one goes
    integer   lost   = 0;
    integer   taken  = 0;
    integer   errors = 0;

    // What a tick does to the list, as the queue should do it.
    always @(posedge clk) begin
        if (put) begin
            if (tail - head < 255) begin
                list[tail % 4096] <= data;
                tail <= tail + 1;
            end else begin
                lost <= lost + 1;
            end
        end
        if (take && tail != head) begin
            head  <= head + 1;
            taken <= taken + 1;
        end
    end

    // Between two ticks: ready says whether the list is empty, and, one tick
    // after the list changed, first is its first byte.
    integer settled = 0;
    integer checks  = 0;        // times first was compared with the list
    always @(negedge clk) begin
        if (ready !== (tail != head)) begin
            errors = errors + 1;
            if (errors <= 10) $display("wrong: ready is %b with %0d bytes in the list", ready, tail - head);
        end
        if (tail != head && settled) begin
            checks = checks + 1;
            if (first !== list[head % 4096]) begin
                errors = errors + 1;
                if (errors <= 10) $display("wrong: first is %h, the list begins with %h", first, list[head % 4096]);
            end
        end
    end

    // first is read at the same tick as the counters change: it shows the
    // byte that was first before that tick. Compare it only after a tick
    // where nothing went in or out.
    always @(posedge clk) begin
        settled <= !(put | take);
    end

    integer i;
    integer seed = 21;
    initial begin
        // 1. Full, then one more.
        @(negedge clk);
        for (i = 0; i < 256; i = i + 1) begin
            put  = 1;
            data = i;
            @(negedge clk);
        end
        put = 0;
        @(negedge clk);
        @(negedge clk);
        $display("1. 256 bytes put in a row: %0d in the queue, %0d lost", tail - head, lost);
        if (tail - head != 255 || lost != 1) errors = errors + 1;
        while (ready) begin
            take = 1;
            @(negedge clk);
            take = 0;
            @(negedge clk);
            @(negedge clk);
        end
        $display("   all taken, in order: %0d", taken);

        // 3. Taking from an empty queue.
        take = 1;
        @(negedge clk);
        take = 0;
        @(negedge clk);
        if (ready !== 0 || taken != 255) begin
            $display("wrong: taking from an empty queue changed something");
            errors = errors + 1;
        end
        $display("3. a byte taken from the empty queue: nothing changes");

        // 2. At random.
        for (i = 0; i < 4000; i = i + 1) begin
            put  = ($random(seed) & 3) == 0;
            data = $random(seed);
            take = ($random(seed) & 3) == 0;
            @(negedge clk);
        end
        put  = 0;
        take = 0;
        @(negedge clk);
        @(negedge clk);
        $display("2. 4,000 ticks at random: %0d bytes went through, %0d still in the queue, %0d lost, the counters at in = %0d, out = %0d",
                 taken - 255, tail - head, lost - 1, the_queue.in, the_queue.out);

        if (errors == 0)
            $display("PASS: queue, ready right at every tick, first right the %0d times it was looked at, the 256th byte lost", checks);
        else
            $display("FAIL: queue, %0d error(s)", errors);
        $finish;
    end
endmodule
