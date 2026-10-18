# Chapter 20: our own monitor. The circuit is the one from chapter 19; the
# program of the board is now a monitor, monitor.s, which we type to from the
# Mac: it shows and stores bytes of the memory, and runs programs.
#   make program         assemble monitor.s: build/monitor.bin, build/monitor.lst, rom.hex
#   make listing         show the listing of the assembler
#   make disassembly     turn the bytes of the ROM back into instructions
#   make term            talk to the monitor from the Mac: tools/term.py
#   make maze            assemble maze.s for the RAM: build/maze.bin
#   make characters      the same for characters.s: build/characters.bin
#   make send-maze       send maze.s to the monitor, run it, and show what it says
#   make test            run the thirteen test benches
#   make test-frame      run one of them: alu, rom, ram, serial, computer, frame, modes,
#                        arithmetic, branches, stack, interrupts, ports, board
#                        (frame also writes the picture: build/frame.bmp)
#   make board           build the circuit for the board
#   make flash-board     send it to the board
#   make keep-board      write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 25.2

# The building blocks of the computer. Test benches and circuits pick what they need.
BLOCKS  = timer.v rom.v ram.v picture_ram.v alu.v cpu.v receiver.v transmitter.v computer.v
# The building blocks of the picture, from chapters 4 to 6.
PICTURE = raster.v display.v palette.v
# The names of the ALU's operations. alu.v, cpu.v and the test bench of the
# ALU include this file: it is not given to the tools as a file of its own.
NAMES   = alu_operations.vh

test: test-alu test-rom test-ram test-serial test-computer test-frame test-modes test-arithmetic test-branches \
      test-stack test-interrupts test-ports test-board

board: %: $(BUILD)/%.fs

program: rom.hex

# The assembler turns the text of the program into an object file, and writes
# a listing: the text again, with its addresses and its bytes.
$(BUILD)/%.o: %.s
	mkdir -p $(BUILD)
	ca65 -l $(BUILD)/$*.lst -o $@ $<

# The linker puts the program at its place in the memory described by
# memory.cfg, and writes the 16,384 bytes of the ROM. It takes every object
# file the program needs: most need only their own.
$(BUILD)/%.bin: $(BUILD)/%.o memory.cfg
	ld65 -C memory.cfg -o $@ $(filter %.o,$^)

# monitor.s takes in the font, the console and the serial link: when one of
# them changes, it is assembled again.
$(BUILD)/monitor.o: font.s console.s serial.s

# Verilog reads its memories from text files: one byte on each line.
rom.hex: $(BUILD)/monitor.bin
	python3 tools/hex.py $< $@

listing: $(BUILD)/monitor.o
	cat $(BUILD)/monitor.lst

# Talking to the monitor: a terminal on the board's serial port.
term:
	python3 tools/term.py

# A program for the RAM is linked with ram.cfg, not memory.cfg: it begins at
# $0300, and its file holds only its own bytes.
maze characters: %: $(BUILD)/%.bin

$(BUILD)/maze.bin $(BUILD)/characters.bin: $(BUILD)/%.bin: $(BUILD)/%.o ram.cfg
	ld65 -C ram.cfg -o $@ $<

# The test benches type what we would type: the lines of explore.txt, then
# the lines that tools/send.py sends for maze.s. Together: build/session.txt.
$(BUILD)/maze.txt: $(BUILD)/maze.bin tools/send.py
	python3 tools/send.py $< --show > $@

$(BUILD)/session.txt: explore.txt $(BUILD)/maze.txt
	cat $^ > $@

send-%: $(BUILD)/%.bin
	python3 tools/send.py $<

# The disassembler goes the other way: it reads bytes, and writes them as
# instructions. The ROM begins with the font, 760 bytes that are pictures,
# not instructions: disassembly.info tells da65 so, and it writes them as
# bytes. We show the 40 lines from the first label after the font, the
# console's first instruction. The tables after the code are data too, and
# da65 shows them as instructions all the same.
disassembly: $(BUILD)/monitor.bin disassembly.info
	da65 --comments 3 --info disassembly.info -o $(BUILD)/monitor.dis $<
	sed -n '/^L[0-9A-F]*:/,$$p' $(BUILD)/monitor.dis | head -n 40

# Simulation: iverilog compiles a test bench, vvp runs it.
# The waveform (.vcd) lands in $(BUILD), next to the compiled test bench.
# A test bench is compiled again when $(NAMES) changes, but iverilog only
# receives the .v files: that is what the filter is for.
$(BUILD)/%_tb.vvp: %_tb.v $(BLOCKS) $(NAMES)
	mkdir -p $(BUILD)
	iverilog -s $*_tb -o $@ $(filter %.v,$^)

# Two test benches need the picture as well: frame and board. The board's
# also needs the board itself, and the files from chapter 5 that end at the pins.
$(BUILD)/frame_tb.vvp: $(PICTURE)
$(BUILD)/board_tb.vvp: board.v $(PICTURE) tmds.v serializer.v pll.v

# Three test benches type to the monitor, as we do from the Mac: mac.v plays
# the Mac, and types build/session.txt. computer_tb also checks the RAM against
# maze.bin and characters.bin.
$(BUILD)/computer_tb.vvp $(BUILD)/frame_tb.vvp $(BUILD)/board_tb.vvp: mac.v
test-computer test-frame test-board: $(BUILD)/session.txt
test-computer: $(BUILD)/maze.bin $(BUILD)/characters.bin

test-%: $(BUILD)/%_tb.vvp
	cd $(BUILD) && vvp $*_tb.vvp

# Some test benches read files: the one that fills the ROM, and the palette.
# They run in $(BUILD), so they need a copy there, made again when it changes.
test-rom test-computer test-frame test-board: $(BUILD)/rom.hex
test-frame test-board: $(BUILD)/palette.hex

$(BUILD)/rom.hex: rom.hex
	mkdir -p $(BUILD)
	cp rom.hex $(BUILD)

$(BUILD)/palette.hex: palette.hex
	mkdir -p $(BUILD)
	cp palette.hex $(BUILD)

# Six more run programs of their own, modes.s, arithmetic.s, branches.s,
# stack.s, interrupts.s and ports.s. Nothing else needs those programs, so
# their bytes are written straight into $(BUILD).
test-modes: $(BUILD)/modes.hex
test-arithmetic: $(BUILD)/arithmetic.hex
test-branches: $(BUILD)/branches.hex
test-stack: $(BUILD)/stack.hex
test-interrupts: $(BUILD)/interrupts.hex
test-ports: $(BUILD)/ports.hex

# The programs from chapters 10 to 14 have no vectors: vectors.s gives them
# theirs, which point at $C000, where they have always begun.
$(BUILD)/modes.bin $(BUILD)/arithmetic.bin $(BUILD)/branches.bin $(BUILD)/stack.bin $(BUILD)/ports.bin: $(BUILD)/vectors.o

$(BUILD)/modes.hex: $(BUILD)/modes.bin
	python3 tools/hex.py $< $@

$(BUILD)/arithmetic.hex: $(BUILD)/arithmetic.bin
	python3 tools/hex.py $< $@

$(BUILD)/branches.hex: $(BUILD)/branches.bin
	python3 tools/hex.py $< $@

$(BUILD)/stack.hex: $(BUILD)/stack.bin
	python3 tools/hex.py $< $@

$(BUILD)/interrupts.hex: $(BUILD)/interrupts.bin
	python3 tools/hex.py $< $@

$(BUILD)/ports.hex: $(BUILD)/ports.bin
	python3 tools/hex.py $< $@

# The board: the same four tools as in chapter 1. Yosys reads rom.hex and
# palette.hex while it builds the memories, so a new program means a new circuit.
# nextpnr is told the clock of the circuit: 25.2 MHz now, the pixel clock.
$(BUILD)/%.json: %.v $(BLOCKS) $(PICTURE) tmds.v serializer.v pll.v $(NAMES) rom.hex palette.hex
	mkdir -p $(BUILD)
	yosys -q -p "read_verilog $(filter %.v,$^); synth_gowin -top top -json $@"

$(BUILD)/%_pnr.json: $(BUILD)/%.json %.cst
	nextpnr-himbaechel --json $< --write $@ --device $(DEVICE) \
		--vopt family=$(FAMILY) --vopt cst=$*.cst --freq $(FREQ)

$(BUILD)/%.fs: $(BUILD)/%_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

flash-%: $(BUILD)/%.fs
	openFPGALoader -b tangnano20k $<

# The same, into the board's permanent memory: the circuit will still be
# there when the board is unplugged and plugged in again.
keep-%: $(BUILD)/%.fs
	openFPGALoader -b tangnano20k -f $<

clean:
	rm -rf $(BUILD)

.PHONY: test board program listing disassembly term maze characters clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json $(BUILD)/%.o $(BUILD)/%.bin
