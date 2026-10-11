# The 6502, Gate by Gate

This is the code of Gate by Gate, a video series and a book in which we write a 6502 computer from scratch, in Verilog, for one small FPGA board: the Sipeed Tang Nano 20K.

We start with a single gate and a blinking LED. The goal is a computer that shows its picture on an HDMI screen, reads a USB keyboard and runs BASIC. The processor is our own, written line by line.

The code grows one chapter at a time. Each folder holds the code as it stands at the end of its chapter, with its test benches and its Makefile. Each folder also stands on its own: when a chapter needs a file from an earlier one, it keeps its own copy.

## Where it stands

| Folder | Chapter | What you see at the end |
|---|---|---|
| `01-box-of-gates` | 1. An FPGA Is a Box of Gates | An LED driven by two buttons through one gate, then an LED that blinks |
| `02-logic-that-computes` | 2. Logic That Computes | An eight-bit addition done by our gates, in simulation and then on the board |
| `03-logic-that-remembers` | 3. Logic That Remembers | A counter on the six LEDs, then a light that runs back and forth |
| `04-how-a-screen-is-drawn` | 4. How a Screen Is Drawn | A test pattern computed in the simulator and written to a picture file |
| `05-driving-an-hdmi-screen` | 5. Driving an HDMI Screen | The same test pattern on a real monitor |
| `06-320-by-200` | 6. 320 by 200 | A picture of 320 by 200 pixels in sixteen colors on that monitor |
| `07-what-a-processor-really-does` | 7. What a Processor Really Does | A first program of eleven bytes, assembled by hand and then by an assembler, which gives the same bytes |
| `08-memory-the-bus-and-the-first-fetch` | 8. Memory, the Bus and the First Fetch | A ROM, a RAM, a bus and the first piece of the processor: it fetches the eleven bytes one by one, in the simulator |
| `09-the-alu` | 9. The ALU | The part that computes: thirteen operations and four flags, checked in the simulator |
| `10-first-instructions` | 10. First Instructions | Our processor runs its first program: five instructions, and the six LEDs of the board count |

The processor knows five opcodes out of 151 so far. The rest comes next, from chapter 11 on.

## What you need

- A Sipeed Tang Nano 20K and a USB-C cable. From chapter 5 on, an HDMI monitor and its cable.
- The OSS CAD Suite. It is free and it holds every tool used here: Yosys, nextpnr, `gowin_pack`, openFPGALoader and Icarus Verilog. It exists for macOS, Linux and Windows: https://github.com/YosysHQ/oss-cad-suite-build/releases/latest
- From chapter 7 on, cc65. It is free too, and it holds the assembler `ca65`, the linker `ld65` and the disassembler `da65`: https://cc65.github.io/getting-started.html
- `make`, and Python 3 from chapter 6 on.

Take a recent build of the suite. Chapter 6 keeps its picture in the block memory of the chip, and with a build from April 2026 that picture came out wrong on my monitor. With the build of October 7, 2026 it is right.

## How to use it

Open a terminal in the folder of a chapter. Here is chapter 3, with the suite unpacked in your home folder:

```
source ~/oss-cad-suite/environment   # once in each terminal
make test          # run the test benches in the simulator
make count         # build the counter
make flash-count   # send it to the board
make keep-count    # or write it into the board's permanent memory
```

A circuit sent with `flash` is gone when the board loses power. `keep` makes it stay.

The circuits have other names in the other chapters: the top of each Makefile lists them. Everything the tools write goes into a `build` folder inside the chapter.

## The videos and the book

The videos show every line being written and explain it. The page of the series is https://yvesrobert.com/6502 and the videos are on YouTube: https://www.youtube.com/@yvesrob

The book, *The 6502, Gate by Gate*, goes through the same chapters for those who would rather read than pause a video. It is sold while it is being written, as an early access edition, and every new chapter is free for those who already have it: https://payhip.com/b/9RyvQ

## How it is written

I write this code with the help of Claude, the AI model made by Anthropic. Every circuit that goes on the board has run on my own Tang Nano 20K before it lands here.

## License

MIT: copy it, change it, build on it. The text is in the `LICENSE` file. It covers the code in this repository, not the book or the videos.
