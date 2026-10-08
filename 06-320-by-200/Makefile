# Chapter 6: turn a picture into two files, test the display that reads them,
# look at the result in a file, then send it to the Tang Nano 20K and a monitor.
#   make picture         turn picture.bmp into bitmap.hex and colors.hex
#   make title           draw picture.bmp, the title picture
#   make photo           the same as picture, with a photograph: photo.bmp
#   make palette NAME=spectrum    change the sixteen colors: c64, spectrum, modern
#   make test            run the three test benches
#   make test-frame      run one of them: palette, memory, frame
#                        (frame also writes the picture: build/frame.bmp)
#   make screen          build the circuit for the board
#   make flash-screen    send it to the board
#   make keep-screen    write it into the board's permanent memory instead
BUILD  ?= build
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
FREQ    = 27

# The building blocks of this chapter. Test benches and circuits pick what they need.
BLOCKS  = raster.v memory.v palette.v display.v tmds.v serializer.v pll.v
# The three files that fill the memories: the picture, its colors, the palette.
MEMORY  = bitmap.hex colors.hex palette.hex

test: test-palette test-memory test-frame

screen: %: $(BUILD)/%.fs

# The picture: a small program in Python turns it into the two files.
# --strip adds the sixteen colors of the palette along the bottom.
picture:
	python3 tools/picture.py picture.bmp

# Another palette: c64, spectrum or modern. The picture files depend on the
# palette, so they are made again.
NAME ?= c64
palette:
	cp palette-$(NAME).hex palette.hex
	python3 tools/title.py
	python3 tools/picture.py picture.bmp

# The title picture is drawn by a second small program...
title:
	python3 tools/title.py

# ...and a photograph shows what two colors for each cell cost.
photo:
	python3 tools/picture.py photo.bmp --strip

# Simulation: iverilog compiles a test bench, vvp runs it.
# The waveform (.vcd) and the picture (.bmp) land in $(BUILD). The test benches
# run there, so they need a copy of the three memory files next to them.
$(BUILD)/%_tb.vvp: %_tb.v $(BLOCKS)
	mkdir -p $(BUILD)
	iverilog -s $*_tb -o $@ $^

test-%: $(BUILD)/%_tb.vvp $(MEMORY)
	cp $(MEMORY) $(BUILD)
	cd $(BUILD) && vvp $*_tb.vvp

# The board: the same four tools as in chapter 1. Yosys reads the three memory
# files while it builds the memories, so a new picture means a new circuit.
$(BUILD)/%.json: %.v $(BLOCKS) $(MEMORY)
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

.PHONY: test screen picture title photo palette clean
.PRECIOUS: $(BUILD)/%_tb.vvp $(BUILD)/%.json $(BUILD)/%_pnr.json
