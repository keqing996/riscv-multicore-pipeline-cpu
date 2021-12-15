# Default target
all: sim

# Compile and run simulation
sim:
	mkdir -p sim
	iverilog -o sim/pc_tb.vvp -I rtl tb/pc_tb.v rtl/pc.v
	vvp sim/pc_tb.vvp

# Clean generated files
clean:
	rm -rf sim/*

.PHONY: all sim clean
