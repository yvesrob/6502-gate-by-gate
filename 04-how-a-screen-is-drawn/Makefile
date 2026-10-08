# Chapter 4: test the two counters that draw a picture, look at that picture
# in a file, then send a second clock to the Tang Nano 20K.
#   make test            run the three test benches
#   make test-raster     run one of them: raster, pattern, frame
#   make test-frame      also writes the picture: build/frame.bmp
#   make two_clocks      build the circuit with the two clocks
#   make flash-two_clocks    send it to the board
#   make keep-two_clocks    write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = raster.v pattern.v timer.v pll.v

test: test-raster test-pattern test-frame

two_clocks: %: $(BUILD)/%.fs

# Simulation: iverilog compiles a test bench, vvp runs it.
# The waveform (.vcd) and the picture (.bmp) land in $(BUILD).
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

.PHONY: test two_clocks clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json
