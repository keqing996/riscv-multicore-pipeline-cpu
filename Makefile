# Default target
all: pc_sim imem_sim

# PC Simulation
pc_sim:
	mkdir -p sim
	iverilog -o sim/pc_tb.vvp -I rtl tb/pc_tb.v rtl/pc.v
	cd sim && vvp pc_tb.vvp

# IMEM Simulation
imem_sim:
	mkdir -p sim
	# Copy hex file from tb/ to sim/ for the simulation to read
	cp tb/program.hex sim/program.hex
	iverilog -o sim/imem_tb.vvp -I rtl tb/imem_tb.v rtl/imem.v
	cd sim && vvp imem_tb.vvp

# Clean generated files
clean:
	rm -rf sim/*.vvp sim/*.vcd

.PHONY: all sim clean
