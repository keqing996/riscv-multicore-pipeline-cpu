LLVM_PATH = /opt/homebrew/opt/llvm/bin
CC = $(LLVM_PATH)/clang
OBJCOPY = $(LLVM_PATH)/llvm-objcopy
OBJDUMP = $(LLVM_PATH)/llvm-objdump

# Flags
CFLAGS = --target=riscv32 -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -O2 -g -Wall
LDFLAGS = -T link.ld

all: program.hex

program.elf: start.S main.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

program.bin: program.elf
	$(OBJCOPY) -O binary $< $@

program.hex: program.bin
	python3 make_hex.py $< > $@

dump: program.elf
	$(OBJDUMP) -d $<

clean:
	rm -f *.elf *.bin *.hex
