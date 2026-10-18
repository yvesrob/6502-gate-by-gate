# Chapter 23: Running the BASIC Bill Gates Wrote

This folder runs Microsoft's BASIC for the 6502 on our computer: the circuit from chapter 21, the monitor and the keyboard from chapter 22, and the BASIC in the ROM from `$D000`. From the monitor, `D000R` starts it.

The BASIC itself is not in this folder.

## Where the BASIC comes from

Microsoft published the source of its BASIC for the 6502, version 1.1, in September 2025: https://github.com/microsoft/BASIC-M6502. Microsoft writes that the 6502 port was completed in 1976 by Bill Gates and Ric Weiland. That file, `m6502.asm`, is written for an assembler of its time, and we do not assemble it.

We assemble `mist64/msbasic` instead: a source for the assembler ca65 in which Michael Steil and others rebuilt Microsoft's BASIC for the 6502, as nine machines of the time had it, byte for byte. We take it at one commit, `2a0bc2fe0db13f8cf1b5c40b1d5617263cdb9cb4`, and change none of its files: https://github.com/mist64/msbasic. Our BASIC is none of those nine: `basic.s` chooses its own settings, and gives it what it needs from our computer.

The first time, `make program` fetches that commit into `build/msbasic`, with `curl` and `tar`: you need an internet connection once. After that, the copy in `build/msbasic` is used. `make clean` removes it with the rest of `build`. I have done this on my Mac only.

`rom.hex` is not in this folder either: it would hold the bytes of the BASIC. `make program` builds it.

## What is ours

`basic.s`, `basic.cfg`, `tools/rom.py`, and the rule of the `Makefile` that fetches the BASIC. The other files come from earlier chapters, or are test benches and texts that they type, as in every chapter. They are under the MIT license, as is the rest of this repository (`../LICENSE`).

## Licenses

This is what the texts say; it is not legal advice.

Microsoft's source is under the MIT license. Its notice, as Microsoft's file `LICENSE` gives it:

```
MIT License 

    Copyright (c) Microsoft Corporation.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE
```

The README of `mist64/msbasic` says, under "License": "2-clause BSD". Its repository has no file with the text of that license and no copyright line. It also holds the ROM images of the original machines, in its folder `orig`, and comments taken from Bob Sander-Cederlof's disassembly of AppleSoft II, whose license it does not state. So this folder holds none of it: `make` fetches it.
