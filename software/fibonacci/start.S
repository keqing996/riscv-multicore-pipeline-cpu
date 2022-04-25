.section .text
.global _start

_start:
    # Initialize Stack Pointer
    # Stack top is defined in linker script (link.ld)
    la sp, _stack_top

    # Call main function
    call main

    # Infinite loop if main returns
loop:
    j loop

