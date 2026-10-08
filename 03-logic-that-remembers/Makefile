# Chapter 3: test the flip-flop and what we build from it, then send
# a counter to the Tang Nano 20K.
#   make test            run the six test benches
#   make test-counter    run one of them: flipflop, swap, register, counter, timer, scanner
#   make count           build the counter on the six LEDs
#   make scan            build the light that runs back and forth
#   make flash-count / flash-scan    send it to the board
#   make keep-count    write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = flipflop.v swap.v register.v counter.v timer.v scanner.v

test: test-flipflop test-swap test-register test-counter test-timer test-scanner

count scan: %: $(BUILD)/%.fs

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

.PHONY: test count scan clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json
