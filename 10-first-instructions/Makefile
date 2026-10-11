# Chapter 10: the processor runs its first program. Test it in the simulator,
# then send the computer to the Tang Nano 20K and watch the LEDs count.
#   make program         assemble count.s: build/count.bin, build/count.lst, rom.hex
#   make check           compare count-by-hand.hex with what the assembler wrote
#   make listing         show the listing of the assembler
#   make disassembly     turn the bytes of the ROM back into instructions
#   make test            run the six test benches
#   make test-computer   run one of them: alu, rom, ram, computer, ports, board
#   make board           build the circuit for the board
#   make flash-board     send it to the board
#   make keep-board      write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = timer.v rom.v ram.v alu.v cpu.v computer.v
# The names of the ALU's operations. alu.v, cpu.v and the test bench of the
# ALU include this file: it is not given to the tools as a file of its own.
NAMES   = alu_operations.vh

test: test-alu test-rom test-ram test-computer test-ports test-board

board: %: $(BUILD)/%.fs

program: rom.hex

# The assembler turns the text of the program into an object file, and writes
# a listing: the text again, with its addresses and its bytes.
$(BUILD)/%.o: %.s
	mkdir -p $(BUILD)
	ca65 -l $(BUILD)/$*.lst -o $@ $<

# The linker puts the program at its place in the memory described by
# memory.cfg, and writes the 16,384 bytes of the ROM.
$(BUILD)/%.bin: $(BUILD)/%.o memory.cfg
	ld65 -C memory.cfg -o $@ $<

# Verilog reads its memories from text files: one byte on each line.
rom.hex: $(BUILD)/count.bin
	python3 tools/hex.py $< $@

check: $(BUILD)/count.bin
	python3 tools/compare.py count-by-hand.hex $<

listing: $(BUILD)/count.o
	cat $(BUILD)/count.lst

# The disassembler goes the other way: it reads the bytes of the ROM, which
# starts at $C000, and writes them as instructions. It does this for all
# 16,384 bytes, so we only show the top of its file.
disassembly: $(BUILD)/count.bin
	da65 --comments 3 --start-addr 0xC000 -o $(BUILD)/count.dis $<
	head -n 20 $(BUILD)/count.dis

# Simulation: iverilog compiles a test bench, vvp runs it.
# The waveform (.vcd) lands in $(BUILD), next to the compiled test bench.
# A test bench is compiled again when $(NAMES) changes, but iverilog only
# receives the .v files: that is what the filter is for.
$(BUILD)/%_tb.vvp: %_tb.v $(BLOCKS) $(NAMES)
	mkdir -p $(BUILD)
	iverilog -s $*_tb -o $@ $(filter %.v,$^)

# The test bench of the board needs one more file: the board itself.
$(BUILD)/board_tb.vvp: board.v

test-%: $(BUILD)/%_tb.vvp
	cd $(BUILD) && vvp $*_tb.vvp

# Three of the test benches read the file that fills the ROM. They run in
# $(BUILD), so they need a copy of it there, made again when the program changes.
test-rom test-computer test-board: $(BUILD)/rom.hex

$(BUILD)/rom.hex: rom.hex
	mkdir -p $(BUILD)
	cp rom.hex $(BUILD)

# A fourth one runs a program of its own, ports.s. Nothing else needs that
# program, so its bytes are written straight into $(BUILD).
test-ports: $(BUILD)/ports.hex

$(BUILD)/ports.hex: $(BUILD)/ports.bin
	python3 tools/hex.py $< $@

# The board: the same four tools as in chapter 1. Yosys reads rom.hex while it
# builds the ROM, so a new program means a new circuit.
$(BUILD)/%.json: %.v $(BLOCKS) $(NAMES) rom.hex
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

.PHONY: test board program check listing disassembly clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json $(BUILD)/%.o $(BUILD)/%.bin
