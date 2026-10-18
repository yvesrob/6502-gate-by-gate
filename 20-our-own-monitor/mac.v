// Chapter 20: the Mac, for the test benches. It types to the monitor what we
// would type, as tools/term.py and tools/send.py send it. It reads the lines
// to type from a text file, build/session.txt: the lines of explore.txt, then
// those that tools/send.py sends for maze.s. Two keys that a text file cannot
// show are written as in caret notation: ^? for Delete, ^[ for Escape. Each
// line feed of the file is typed as a Return.
//
// First it waits for the monitor's first prompt; then it types Escape, as
// tools/send.py does, and waits for the prompt again. Then a line at a time:
// it types the line, its characters one right after the other, as fast as
// the link goes, then waits for the monitor's prompt, *, once for each Return
// and each Escape in the line. The last line runs maze.s, which never comes
// back: for it the Mac only waits for the echo. Then done is 1, and the Mac
// goes on listening: what maze.s says comes after, and the Mac writes it,
// line by line. It keeps everything it hears, from the start, in heard.
//
// Its bits last 8,746 ns, 218.65 ticks of the test benches' 40 ns. On the
// board, 218.65 ticks of the pixel clock make the bit that the board's USB
// chip sent to ours, measured in chapter 19: 11,525 bytes a second. It hears
// ours at that speed too.
`timescale 1ns/1ns
module mac (
    input  wire go,         // 1: start typing
    input  wire tx,         // from our computer
    output reg  rx   = 1,   // to our computer: 1 when nothing is sent
    output reg  done = 0    // 1: everything was typed, and the last line came back
);
    parameter FILE  = "session.txt";
    parameter BIT   = 8746;         // nanoseconds
    parameter LIMIT = 50_000_000;   // how long it waits for a prompt: 50 ms

    reg [7:0] text  [0:8191];       // what it types
    integer   length  = 0;
    reg [7:0] heard [0:16383];      // what it hears, in order, from the start
    integer   count   = 0;
    integer   prompts = 0;          // prompts heard
    integer   lines   = 0;          // lines typed
    integer   late    = 0;          // lines whose prompts did not all come within 50 ms
    integer   broken  = 0;          // bytes heard without their stop bit
    integer   typed_at [0:255];     // where, in heard, the echo of each line begins
    integer   said_from = -1;       // where the line the program is saying began

    // The text, byte after byte: ^? is Delete, ^[ is Escape, a line feed is
    // a Return.
    integer f;
    integer c;
    integer after;
    initial begin
        f = $fopen(FILE, "rb");
        if (f == 0) begin
            $display("FAIL: the Mac cannot read %0s", FILE);
            $finish;
        end
        c = $fgetc(f);
        while (c != -1) begin
            if (c == "^") begin
                after = $fgetc(f);
                c = (after == "?") ? 127 : (after == "[") ? 27 : after;
            end
            text[length] = (c == 10) ? 13 : c;
            length = length + 1;
            c = $fgetc(f);
        end
        $fclose(f);
    end

    // Listening: a falling edge is a start bit; then the middle of each bit.
    reg [7:0] byte_heard;
    integer   k;
    initial begin
        forever begin
            @(negedge tx);
            #(BIT / 2);
            if (tx == 0) begin
                for (k = 0; k < 8; k = k + 1) begin
                    #(BIT);
                    byte_heard[k] = tx;
                end
                #(BIT);                 // the middle of the stop bit: it must be 1
                if (tx !== 1) broken = broken + 1;
                heard[count] = byte_heard;
                count = count + 1;
                if (byte_heard == "*") prompts = prompts + 1;
                if (done && said_from >= 0 && byte_heard == 10) begin
                    // After the last line: what the program says, a line at a time.
                    $write("the Mac hears: ");
                    for (k = said_from; k < count; k = k + 1) begin
                        if (heard[k] != 13 && heard[k] != 10) $write("%c", heard[k]);
                    end
                    $display("");
                    said_from = count;
                end
            end
        end
    end

    // Typing one key: the start bit, the eight bits from the lowest, the stop bit.
    task send_byte(input [7:0] value);
        integer b;
        begin
            rx = 0;
            #(BIT);
            for (b = 0; b < 8; b = b + 1) begin
                rx = value[b];
                #(BIT);
            end
            rx = 1;
            #(BIT);
        end
    endtask

    // Waiting until what is heard reaches a number of prompts, or a number of
    // bytes; 50 ms at most. A line that waits longer is late.
    integer waited;
    task wait_for(input integer expected_prompts, input integer expected_count);
        begin
            waited = 0;
            while ((prompts < expected_prompts || count < expected_count) && waited < LIMIT) begin
                #10000;
                waited = waited + 10000;
            end
            if (prompts < expected_prompts || count < expected_count) late = late + 1;
        end
    endtask

    integer i;
    integer first;
    integer ends;
    integer prompts_before;
    initial begin
        wait (go);
        // The monitor's first prompt, then Escape, and the prompt again.
        wait_for(1, 0);
        prompts_before = prompts;
        send_byte(27);
        wait_for(prompts_before + 1, 0);
        i = 0;
        while (i < length) begin
            first = i;
            ends = 0;
            prompts_before = prompts;
            typed_at[lines] = count;
            while (i < length && (i == first || text[i - 1] != 13)) begin
                if (text[i] == 13 || text[i] == 27) ends = ends + 1;
                send_byte(text[i]);
                i = i + 1;
            end
            if (i < length) begin
                wait_for(prompts_before + ends, 0);
            end else begin
                // The last line runs a program: only its echo, the Return
                // coming back as a carriage return and a line feed.
                wait_for(0, typed_at[lines] + (i - first) + 1);
                said_from = typed_at[lines] + (i - first) + 1;
            end
            lines = lines + 1;
        end
        done = 1;
    end
endmodule
