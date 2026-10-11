# Chapter 7: assemble the first program of our computer, and compare it with
# the bytes we worked out by hand.
#   make program        assemble count.s: build/count.bin, build/count.lst, rom.hex
#   make check          compare count-by-hand.hex with what the assembler wrote
#   make listing        show the listing of the assembler
#   make disassembly    turn the bytes of the ROM back into instructions
BUILD ?= build

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

clean:
	rm -rf $(BUILD)

.PHONY: program check listing disassembly clean
.PRECIOUS: $(BUILD)/%.o $(BUILD)/%.bin
