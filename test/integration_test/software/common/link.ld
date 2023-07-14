OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  /* Define RAM size here - 64KB to match main_memory.v */
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text)
    *(.text.*)
  } > RAM
  
  .rodata : {
    *(.rodata)
    *(.rodata.*)
  } > RAM
  
  .data : {
    *(.data)
    *(.data.*)
    *(.sdata)
    *(.sdata.*)
  } > RAM
  
  .bss : {
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
  } > RAM

  /* Define stack top at the end of RAM */
  PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));
}
