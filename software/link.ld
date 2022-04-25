OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  /* Define RAM size here - currently 32MB */
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32M
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text)
    *(.text.*)
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
