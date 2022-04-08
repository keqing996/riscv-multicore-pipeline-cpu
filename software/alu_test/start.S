.section .text
.global _start

_start:
    # Initialize Stack Pointer
    li sp, 0x1000

    # Call main function
    call main

    # Infinite loop
loop:
    j loop
