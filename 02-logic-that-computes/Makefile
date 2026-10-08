# Chapter 2: test the adders in simulation, then send one to the Tang Nano 20K.
#   make test               run the four test benches
#   make test-half_adder    run one of them: gates, half_adder, full_adder, adder8
#   make add_bits           build the addition of the two buttons
#   make add_numbers        build the eight-bit addition
#   make flash-add_bits / flash-add_numbers    send it to the board
#   make keep-add_bits    write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = gates.v half_adder.v full_adder.v adder8.v

test: test-gates test-half_adder test-full_adder test-adder8

add_bits add_numbers: %: $(BUILD)/%.fs

# Simulation: iverilog compiles a test bench, vvp runs it.
# The waveform (.vcd) lands in $(BUILD), next to the compiled test bench.
$(BUILD)/%_tb.vvp: %_tb.v $(BLOCKS)
	mkdir -p $(BUILD)
	iverilog -s $*_tb -o $@ $^

test-%: $(BUILD)/%_tb.vvp
	cd $(BUILD) && vvp $*_tb.vvp

# The board: the same four tools as in chapter 1.
$(BUILD)/%.json: %.v $(BLOCKS)
	mkdir -p $(BUILD)
	yosys -q -p "read_verilog $^; synth_gowin -top top -json $@"

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

.PHONY: test add_bits add_numbers clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json
