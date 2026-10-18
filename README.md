# Our Own 6502, Gate by Gate

This is the code of Gate by Gate, a video series and a book in which we write a 6502 computer from scratch, in Verilog, for one small FPGA board: the Sipeed Tang Nano 20K.

We start with a single gate and a blinking LED. By chapter 23, the computer shows its picture on an HDMI screen, reads a USB keyboard and runs the BASIC that Microsoft wrote for the 6502. The processor is our own, written line by line.

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
| `11-addressing-modes` | 11. Addressing Modes | A light two LEDs wide sweeps across the board, read from a table |
| `12-arithmetic-compares-and-decimal-mode` | 12. Arithmetic, Compares and Decimal Mode | A stopwatch that counts the seconds in decimal on the six LEDs |
| `13-branches-and-loops` | 13. Branches and Loops | A loop that computes the Collatz sequence on the six LEDs and stops by itself on 1 |
| `14-the-stack-and-subroutines` | 14. The Stack and Subroutines | A subroutine that calls itself makes a bar of light grow and shrink on the six LEDs |
| `15-reset-and-interrupts` | 15. Reset and Interrupts | A light walks along the six LEDs; button S2 interrupts it, and it goes on from where it was |
| `16-is-it-really-a-6502` | 16. Is It Really a 6502? | The functional test of Klaus Dormann runs again and again on the board, at full speed, and the six LEDs count the runs that went well |
| `17-the-processor-draws` | 17. The Processor Draws | The processor draws 128 straight lines on the screen, then changes the colors of the whole picture |
| `18-letters-made-of-pixels` | 18. Letters Made of Pixels | Text on the screen: a few lines, the 95 characters of our font and 48 lines of slanting stripes |
| `19-talking-to-your-computer` | 19. Talking to Your Computer | A program sent from your computer through the USB-C cable draws mazes on the screen |
| `20-our-own-monitor` | 20. Our Own Monitor | A monitor in the ROM: from your computer, you look at the memory, change it and run a program |
| `21-a-real-usb-keyboard` | 21. A Real USB Keyboard | The reports of a real USB keyboard, read through a CH9350 module, on the screen and on your computer |
| `22-from-key-codes-to-characters` | 22. From Key Codes to Characters | The monitor at the keyboard: characters, Shift and AltGr, keys that repeat, Backspace and a blinking cursor |
| `23-running-the-basic-bill-gates-wrote` | 23. Running the BASIC Bill Gates Wrote | Microsoft's BASIC for the 6502 runs on our computer, started from the monitor with `D000R` |

From chapter 15 on, the processor knows all 151 opcodes of the 6502, and in chapter 16 it passes the functional test of Klaus Dormann. These 23 chapters are volume 1 of the series. Volume 2, where we write a BASIC of our own, comes next.

## What you need

- A Sipeed Tang Nano 20K and a USB-C cable. From chapter 5 on, an HDMI monitor and its cable.
- The OSS CAD Suite. It is free and it holds every tool used here: Yosys, nextpnr, `gowin_pack`, openFPGALoader and Icarus Verilog. It exists for macOS, Linux and Windows: https://github.com/YosysHQ/oss-cad-suite-build/releases/latest
- From chapter 7 on, cc65. It is free too, and it holds the assembler `ca65`, the linker `ld65` and the disassembler `da65`: https://cc65.github.io/getting-started.html
- `make`, and Python 3 from chapter 6 on.
- From chapter 21 on, a USB keyboard and the KAmod USB HID Extender from Kamami, a small module with a CH9350 chip, with six header pins, three Dupont wires, a soldering iron and a multimeter.

Take a recent build of the suite. Chapter 6 keeps its picture in the block memory of the chip, and with a build from April 2026 that picture came out wrong on my monitor. With the build of October 7, 2026 it is right.

Chapters 16 and 23 use code that is not ours, and that is not in this repository: the functional test of Klaus Dormann, and Microsoft's BASIC for the 6502 as mist64/msbasic rebuilds it. Their Makefile fetches it the first time, so these two chapters need an internet connection once. The README of chapter 23 says where its BASIC comes from and under which licenses.

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

The book, *Our Own 6502, Gate by Gate*, goes through the same chapters for those who would rather read than pause a video. Its first volume is complete, and those who have it get every new version at no extra cost: https://payhip.com/b/9RyvQ

## How it is written

I write this code with the help of Claude, the AI model made by Anthropic. Every circuit that goes on the board has run on my own Tang Nano 20K before it lands here.

## License

MIT: copy it, change it, build on it. The text is in the `LICENSE` file. It covers the code in this repository, not the book or the videos.
