# Chapter 16: is it really a 6502? The functional test of Klaus Dormann runs
# on our processor, in the simulator, then on the Tang Nano 20K at full speed:
# the LEDs count the times the whole test went well.
#   make program         assemble functional.s: build/functional.bin, build/functional.lst, rom.hex
#   make listing         show the listing of the assembler
#   make disassembly     turn the bytes of our program, at the top of the ROM, back into instructions
#   make test            run the eleven test benches (test-computer takes about a quarter of an hour)
#   make test-interrupts run one of them: alu, rom, ram, computer, modes, arithmetic,
#                        branches, stack, interrupts, ports, board
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

test: test-alu test-rom test-ram test-computer test-modes test-arithmetic test-branches test-stack test-interrupts \
      test-ports test-board

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

# Verilog reads its memories from text files: one byte on each line.
rom.hex: $(BUILD)/functional.bin
	python3 tools/hex.py $< $@

# The test of Klaus Dormann is not ours: it comes from his repository, as he
# assembled it. If the file is not here, make fetches it.
6502_functional_test.bin:
	curl -L -o $@ https://raw.githubusercontent.com/Klaus2m5/6502_65C02_functional_tests/7954e2dbb49c469ea286070bf46cdd71aeb29e4b/bin_files/6502_functional_test.bin

# functional.s takes pages of that file into the ROM (.incbin).
$(BUILD)/functional.o: 6502_functional_test.bin

listing: $(BUILD)/functional.o
	cat $(BUILD)/functional.lst

# The disassembler goes the other way: it reads bytes, and writes them as
# instructions. The first $3900 bytes of our ROM are Klaus Dormann's test, so
# we give it only the last 1,792, from $F900: our program, then the vectors.
disassembly: $(BUILD)/functional.bin
	tail -c 1792 $< > $(BUILD)/top.bin
	da65 --comments 3 --start-addr 0xF900 -o $(BUILD)/top.dis $(BUILD)/top.bin
	head -n 45 $(BUILD)/top.dis

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

.PHONY: test board program listing disassembly clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json $(BUILD)/%.o $(BUILD)/%.bin
