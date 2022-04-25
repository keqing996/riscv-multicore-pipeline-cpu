.section .text
.global _start

_start:
    # Initialize Stack Pointer
    la sp, _stack_top

    # Call main function
    call main

    # Infinite loop
loop:
    j loop
