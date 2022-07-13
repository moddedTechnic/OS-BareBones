
# Assembly

## Directives

### `.align X`
Aligns to an `X`-byte boundary.

### .global NAME
Exports the name `NAME` to be accessible by the linker.

### `.section NAME`
Creates a new section with the name `NAME`, which should be one of:

| Name         | Purpose                               |
| ------------ | ------------------------------------- |
| `.multiboot` | makes a multiboot header              |
| `.bss`       | used to declare variables             |
| `.text`      | used to store the code to be executed |

### `.set NAME, VALUE`
Sets a constant with the name `NAME` to have the value `VALUE`.

### `.skip X`
Leave `X` bytes when buiding the executable.

### .type NAME, TYPE
Declares that the name `NAME` has a value of type `TYPE`, which should be one of:

- `@function`


## Multiboot

There must be a section that acts as a multiboot header, marking the program as a kernel.
This section contains a variety of magic values, documented both below and in the multiboot standard.

The bootloader searches for this signature in the first 8 kiB of the kernel file, which must be aligned at a 32-bit boundary.
The signature is given its own section to ensure that the header is within the firs 8 kiB of the kernel file.

The structure for the header is given below:

```asm
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM
```

### Constants

Some constants are required for the multiboot header to be recognised by the bootloader.

| Constant   | Value                    | Purpose                                                                       |
| ---------- | ------------------------ | ----------------------------------------------------------------------------- |
| `ALIGN`    | `1<<0`                   | Specify that loaded modules should be aligned to page boundaries              |
| `MEMINFO`  | `1<<1`                   | Tell the bootloader to provide us with a memory map                           |
| `FLAGS`    | `ALIGN | MEMINFO | ...`  | Combine each of the flags into one field to be presented to the bootloader    |
| `MAGIC`    |  `0x1BADB002`            | A magic number to tell the bootloader where the header is located             |
| `CHECKSUM` | `-(MAGIC + FLAGS)`       | A checksum of the provided constants to prove that we have the correct format |


### Stack

The multiboot standard does not define the value of the stack pointer register (`esp`)
and it is up to the kernel to provide a stack.

To create the stack, first a label must be created to mark the bottom of the stack, the appropriate space must be left, and another label is created to mark the top.
16 kiB (16384 B) should be enough space for the stack for a small kernel.

The stack is placed in its own section so that it can be marked as `nobits`, whic means the kernel file can be smaller as it does not contain an uninitialised stack.

An example to create a stack is as follows:
```asm
.section .bss
/* Align if necessary */
stack_bottom:
.skip STACK_SIZE
stack_top:
```

#### x86

On x86 architechture, the stack grows downwards.

According to the System V ABI standard and de-facto extensions, the stack should be 16-byte aligned.
The compiler will assume that the stack is properly aligned.
Failure to do so will result in undefined behaviour.


## Entry Point

The linker script specifies the entry point to be `_start`, and the bootloader will jump to this position once the kernel has been loaded.
The `_start` function should not be returned from, as by the point it completes, the bootloader is gone.

An example demarkation entry point is as follows:

```asm
.section .text
.global _start
.type _start, @function
_start:
    /* Place the contents of the start function here */
```

When the `_start` function is called, the processor state is as defined by the multiboot standard, with the kernel being given full control of the CPU.

At this point, the kernel can only make use of hardware features and code that it provides itself.
In other words, there is not `printf` function, unless the kernel provides its own `<stdio.h>` header and mathing `printf` implementation.
There are no security restrictions, no safeguards, and no debugging mechanisms: there is only what the kernel provides.
***The kernel has complete and absolute power over the machine.***

### x86

When the bootloader hands over control, the system will be in 32-bit protected mode, with interrupts and paging **disabled**.


# TODO
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
