# Chapter 5: test the encoder that turns a byte into ten bits, find a whole
# picture back from its codes, then send that picture to a monitor.
#   make test            run the two test benches
#   make test-tmds       run one of them: tmds, screen
#   make test-screen     also writes the picture it found: build/decoded.bmp
#   make screen          build the circuit that drives the HDMI socket
#   make flash-screen    send it to the board
#   make keep-screen    write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = raster.v pattern.v tmds.v serializer.v pll.v

test: test-tmds test-screen

screen: %: $(BUILD)/%.fs

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

.PHONY: test screen clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json
