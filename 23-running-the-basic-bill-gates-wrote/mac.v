// Chapter 23: the Mac, for the test benches. It types what we would type into
// tools/term.py: first to the monitor, then to Microsoft's BASIC. It reads
// the lines to type from a text file, build/session.txt. Two keys that a text
// file cannot show are written as in caret notation: ^? for Delete, ^[ for
// Escape. Each line feed of the file is typed as a Return.
//
// First it waits for the monitor's first prompt; then it types Escape, as in
// chapter 20, and waits for the prompt again. Then it types like a careful
// typist: one key, and it waits to hear that key come back before the next.
// At the end of a line, a Return or an Escape, it waits for the line feed
// that follows, and then for the computer to say that it is ready again: the
// monitor's prompt, * at the start of a line; the BASIC's OK and its line
// feed; or a question mark and a space, as in MEMORY SIZE?. A line that
// begins with a digit, or ends with Escape, may get no such answer: the BASIC
// keeps it, or drops it, and says nothing more. After such a line, a moment
// of silence will do as well: 1 ms here, a tenth of a second in
// tools/term.py, where the USB adds its own delays.
// So it never sends a key while the one before still waits to be read: the
// computer keeps only one. When the file is done, done is 1. The Mac keeps
// everything it hears, from the start, in heard.
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
    output reg  done = 0    // 1: everything was typed, and the computer is ready
);
    parameter FILE  = "session.txt";
    parameter BIT   = 8746;             // nanoseconds
    parameter LIMIT = 64'd4_000_000_000; // how long it waits for an answer: 4 s
    parameter QUIET = 1_000_000;        // the silence that will do after some lines: 1 ms

    reg [7:0] text  [0:8191];       // what it types
    integer   length  = 0;
    reg [7:0] heard [0:65535];      // what it hears, in order, from the start
    integer   count   = 0;
    integer   prompts = 0;          // the monitor's prompts heard
    integer   lines   = 0;          // lines typed
    integer   late    = 0;          // answers that did not come within 4 s
    integer   broken  = 0;          // bytes heard without their stop bit
    integer   typed_at [0:255];     // where, in heard, the echo of each line begins
    integer   ready_at [0:255];     // where, in heard, the computer was ready after it
    integer   keys    = 0;          // keys typed
    reg [7:0] key     [0:8191];     // each key typed,
    integer   key_at  [0:8191];     // and how much the Mac had heard when it typed it

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
    reg [63:0] heard_when = 0;      // when the last byte came
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
                heard_when = $time;
                if (byte_heard == "*") prompts = prompts + 1;
            end
        end
    end

    // Typing one key: the start bit, the eight bits from the lowest, the stop bit.
    task send_byte(input [7:0] value);
        integer b;
        begin
            key[keys] = value;
            key_at[keys] = count;
            keys = keys + 1;
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

    // Is the computer ready for a new line? The last bytes heard say so.
    function ready(input integer n);
        ready = (n >= 2 && heard[n - 2] == 10 && heard[n - 1] == "*") ||
                (n >= 2 && heard[n - 2] == "?" && heard[n - 1] == " ") ||
                (n >= 4 && heard[n - 4] == "O" && heard[n - 3] == "K" &&
                           heard[n - 2] == 13 && heard[n - 1] == 10);
    endfunction

    // Waiting until more than a number of bytes have come, and, if asked,
    // until the computer is ready (and_ready 1), or ready or silent for QUIET
    // (and_ready 2); 4 s at most. An answer that waits longer is late.
    reg [63:0] waited;
    function settled(input integer and_ready);
        settled = and_ready == 0 || ready(count) || (and_ready == 2 && $time - heard_when >= QUIET);
    endfunction
    task wait_for(input integer more_than, input integer and_ready);
        begin
            waited = 0;
            while ((count <= more_than || !settled(and_ready)) && waited < LIMIT) begin
                #10000;
                waited = waited + 10000;
            end
            if (count <= more_than || !settled(and_ready)) late = late + 1;
        end
    endtask

    integer i;
    integer first;
    integer count_before;
    initial begin
        wait (go);
        // The monitor's first prompt, then Escape, and the prompt again.
        wait_for(-1, 1);
        count_before = count;
        send_byte(27);
        wait_for(count_before, 1);
        i = 0;
        while (i < length) begin
            first = i;
            typed_at[lines] = count;
            // The keys of the line, each one after the one before has come back.
            while (i < length && text[i] != 13 && text[i] != 27) begin
                count_before = count;
                send_byte(text[i]);
                wait_for(count_before, 0);
                i = i + 1;
            end
            // Its end: the line feed that follows a Return or an Escape...
            count_before = count;
            send_byte(text[i]);
            wait_for(count_before, 0);
            while (heard[count - 1] != 10 && waited < LIMIT) wait_for(count, 0);
            // ...then until the computer is ready again, or, after a line that
            // may get no answer, silent.
            wait_for(count - 1, (text[i] == 27 || (text[first] >= "0" && text[first] <= "9")) ? 2 : 1);
            ready_at[lines] = count;
            i = i + 1;
            lines = lines + 1;
        end
        done = 1;
    end
endmodule
