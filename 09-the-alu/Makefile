# Chapter 9: the ALU and its test bench, next to what chapter 8 built.
#   make program         assemble count.s: build/count.bin, build/count.lst, rom.hex
#   make check           compare count-by-hand.hex with what the assembler wrote
#   make listing         show the listing of the assembler
#   make disassembly     turn the bytes of the ROM back into instructions
#   make test            run the four test benches
#   make test-alu        run one of them: alu, rom, ram, computer
BUILD ?= build

# The building blocks of this chapter. Test benches pick what they need.
BLOCKS = timer.v rom.v ram.v alu.v cpu.v computer.v
# The names of the ALU's operations. alu.v and its test bench include this
# file: it is not given to the compiler as a file of its own.
NAMES  = alu_operations.vh

test: test-alu test-rom test-ram test-computer

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

test-%: $(BUILD)/%_tb.vvp
	cd $(BUILD) && vvp $*_tb.vvp

# Two of the test benches read the file that fills the ROM. They run in
# $(BUILD), so they need a copy of it there, made again when the program changes.
test-rom test-computer: $(BUILD)/rom.hex

$(BUILD)/rom.hex: rom.hex
	mkdir -p $(BUILD)
	cp rom.hex $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: test program check listing disassembly clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.o $(BUILD)/%.bin
