# This makefile runs the tests in each chapter that
# has a test target.

# Chapters 1 and 7 have no tests and are not included
# in this list. Listing these in reverse order is a bit
# of a performance hack, as the most expensive tests will
# run first and in parallel.
TESTED_CHAPTERS := \
	23-running-the-basic-bill-gates-wrote \
	22-from-key-codes-to-characters \
	21-a-real-usb-keyboard \
	20-our-own-monitor \
	19-talking-to-your-computer \
	18-letters-made-of-pixels \
	17-the-processor-draws \
	16-is-it-really-a-6502 \
	15-reset-and-interrupts \
	14-the-stack-and-subroutines \
	13-branches-and-loops \
	12-arithmetic-compares-and-decimal-mode \
	11-addressing-modes \
	10-first-instructions \
	09-the-alu \
	08-memory-the-bus-and-the-first-fetch \
	06-320-by-200 \
	05-driving-an-hdmi-screen \
	04-how-a-screen-is-drawn \
	03-logic-that-remembers \
	02-logic-that-computes

test: $(addprefix test-,$(TESTED_CHAPTERS))

# Recurse into a chapter and run the tests.
test-%:
	$(MAKE) -C $* test
