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

    /*
    To setup a stack, we set the esp register to point to the top of the stack (as it grows
    downwards on x86 systems).
    This is necessarily done in assembly as languages such as C cannot function without a stack.
    */
    mov $stack_top, %esp

    /*
    This is a good place to initialise crucial processor state before the high-level
    kernel is entered.
    It's best to minimise the early environment where crucial features are offline.
    Note that the processor is not fully initialised yet:
        Features such as floating point instructions and instruction set extensions are not
        initialised yet.
    The GDT should be loaded here.
    Paging should be enabled here.
    C++ features such as global constructors and exceptions will require runtime support as well.
    */

    /*
    Enter the high-level kernel.
    The ABI requires the stack is 16-byte aligned at the time of the call instruction
        (which afterwards pushes the return pointer of size 4 bytes).
    The stack was originally 16-byte aligned above and we've pushed a multiple of 16 bytes to the
    stack since (and popped 0 bytes so far), so the alignment has thus been preserved and the call
    is well defined.
    */
    call kernel_main

    /*
    If the system hsa nothing more to do, put the computer into an infinite loop.
    To do that:
    1)  Disable interrupts with cli (clear interrupt enable in eflags).
        They are already disabled in te bootloader, so this is not needed.
        Mind that you might later enable interrupts and return from kernel_main
        (which is sort of nonsensical to do).
    2)  Wait for the next interrupt to arrive with hlt (halt instruction).
        Since they are disabled, this will lock up the computer.
    3)  Jump to the hlt instruction if it ever wakes up due to a non-maskable
        interrupt occurring or due to system management mode.
    */
    cli
1:  hlt
    jmp 1b

/*
Set the size of the start symbol to the curent location `.` minus its start.
This is useful when debugging or when you implement call tracing.
*/
.size _start, . - _start