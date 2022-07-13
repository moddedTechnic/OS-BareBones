/* Declare constants for the multiboot header */
.set ALIGN,    1<<0             /* align loaded modules on page boundaries */
.set MEMINFO,  1<<1             /* provide memory map */
.set FLAGS,    ALIGN | MEMINFO  /* this is the multiboot flag field */
.set MAGIC,    0x1BADB002       /* magic number lets bootloaded find the header */
.set CHECKSUM, -(MAGIC + FLAGS) /* checksum of above, to prove we are multiboot */

/* Declare a multiboot header that marks the program as a kernel. */
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

/*
The multiboot standard does not define the value of the stack pointer register (esp)
and it is up to the kernel to provide a stack.
This then allocates room for a small stack by creating a symbol at the bottom of the it,
then allocating 16384 bytes for it, and finally creating a symbol at the top.
The stack grows downwards on x86.
The stack is in its own section so it can be marked nobits,
which means the kernel file is smaller beacause it does not contain an uninitialised stack.
The stack on x86 must be 16-byte aligned according to the System V ABI standard and
de-facto extensions.
The compiler will assume the stack is properly aligned and failure to align the stack will
result in undefined behaviour.
*/
.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 kiB
stack_top:

/*
The linker script specifies _start as the entry point to the kernel and the bootloader will jump
to this position once the kernel has been loaded.
It doesn't make sense to return from the function as the bootloader is gone.
*/
.section .text
.global _start
.type _start, @function
_start:
    /*
    The bootloader has loaded us into 32-bit prtected mode on an x86 machine.
    Interrupts are disabled.
    Paging is disabled.
    The processor state is as defined by the multiboot standard.
    The kernel has full control of the CPU.
    The kernel can only make use of hardware features and any code it provides as part of itself.
    There's no printf function, unless the kernel provides its own <stdio.h> header
    and a printf implementation.
    There are no security restrictions, no safeguards, no debugging mechanisms, only what the
    kernel provides itself.
    It has absolute and complete power over the machine.
    */
