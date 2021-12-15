# Default target
all: pc_sim imem_sim

# PC Simulation
pc_sim:
	mkdir -p sim
	iverilog -o sim/pc_tb.vvp -I rtl tb/pc_tb.v rtl/pc.v
	vvp sim/pc_tb.vvp

# IMEM Simulation
imem_sim:
	mkdir -p sim
	# Copy hex file to sim directory if it's not there (or just rely on it being in sim/)
	# Here we assume program.hex is already in sim/ or we create a dummy one if needed.
	# But for now, we just run the simulation.
	iverilog -o sim/imem_tb.vvp -I rtl tb/imem_tb.v rtl/imem.v
	cd sim && vvp imem_tb.vvp

# Clean generated files
clean:
	rm -rf sim/*.vvp sim/*.vcd

.PHONY: all sim clean
