.section .text
.global _start

_start:
    # Initialize Stack Pointer
    # DMEM size is 4KB (0x1000 bytes)
    # Stack grows down, so we start at the top
    li sp, 0x1000

    # Call main function
    call main

    # Infinite loop if main returns
loop:
    j loop

