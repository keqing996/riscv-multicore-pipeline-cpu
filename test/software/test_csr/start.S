.section .text.init
.global _start
.global trap_handler

_start:
    la sp, _stack_top
    
    # Setup Trap Vector (mtvec)
    la t0, trap_handler
    csrw mtvec, t0
    
    # Initialize a register to check in testbench
    li s10, 0xDEADBEEF
    
    call main
    
    # End of test
    ebreak

loop:
    j loop

.align 4
trap_handler:
    # Indicate we are in trap handler by writing to s11
    li s11, 0xCAFEBABE
    
    # Read mcause to s2
    csrr s2, mcause
    
    # Read mepc to s3
    csrr s3, mepc
    
    # Increment mepc by 4 to return to next instruction
    addi s3, s3, 4
    csrw mepc, s3
    
    mret
