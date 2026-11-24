
SUBDIRS := \
	01-box-of-gates \
	02-logic-that-computes \
	03-logic-that-remembers \
	04-how-a-screen-is-drawn \
	05-driving-an-hdmi-screen \
	06-320-by-200 \
	07-what-a-processor-really-does \
	08-memory-the-bus-and-the-first-fetch \
	09-the-alu \
	10-first-instructions \
	11-addressing-modes \
	12-arithmetic-compares-and-decimal-mode \
	13-branches-and-loops \
	14-the-stack-and-subroutines \
	15-reset-and-interrupts \
	16-is-it-really-a-6502 \
	17-the-processor-draws \
	18-letters-made-of-pixels \
	19-talking-to-your-computer \
	20-our-own-monitor \
	21-a-real-usb-keyboard \
	22-from-key-codes-to-characters \
	23-running-the-basic-bill-gates-wrote

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done

test:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir test; \
	done
