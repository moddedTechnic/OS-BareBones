
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

| Constant   | Value                                  | Purpose                                                                       |
| ---------- | ------------------------               | ----------------------------------------------------------------------------- |
| `ALIGN`    | `1<<0`                                 | Specify that loaded modules should be aligned to page boundaries              |
| `MEMINFO`  | `1<<1`                                 | Tell the bootloader to provide us with a memory map                           |
| `FLAGS`    | Bitwise or of all the flags to be set  | Combine each of the flags into one field to be presented to the bootloader    |
| `MAGIC`    |  `0x1BADB002`                          | A magic number to tell the bootloader where the header is located             |
| `CHECKSUM` | `-(MAGIC + FLAGS)`                     | A checksum of the provided constants to prove that we have the correct format |


### Stack

The multiboot standard does not define the value of the stack pointer register (`esp`) and it is up to the kernel to provide a stack.

To create the stack, first a label must be created to mark one end of the stack, the appropriate space must be left, and another label is created to mark the other end.
16 kiB (16384 B) should be enough space for the stack for a small kernel.

The stack is placed in its own section so that it can be marked as `nobits`, whic means the kernel file can be smaller as it does not contain an uninitialised stack.

An example to create a stack is as follows:
```asm
.section .bss
/* Align if necessary */
stack_end1:
.skip STACK_SIZE
stack_end2:
```

To finish setting up the stack, the `esp` register must be set to point to the top of the stack within the entry point.
This must be done in assembly language, as many languages, such as C, cannot function without a stack.
The stack pointer can be initialised as follows:
```asm
mov $stack_top, %esp
```

#### x86

On x86 architechture, the stack grows downwards. As such, the first end should be the bottom, and the second end should be the top of the stack.

According to the System V ABI standard and de-facto extensions, the stack should be 16-byte aligned.
The compiler will assume that the stack is properly aligned.
Failure to do so will result in undefined behaviour.

An example of creating a stack for x86 architectures is given below:
An example to create a stack is as follows:
```asm
.section .bss
.align 16
stack_bottom:
.skip STACK_SIZE
stack_top:
```


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

The entry point should also have its size set for debugging and to assist in implementing call tracing.
To do this, immediately after the `_start` function, the following code snippet can be inserted:
```asm
.size _start, . - _start
```

When the `_start` function is called, the processor state is as defined by the multiboot standard, with the kernel being given full control of the CPU.

At this point, the kernel can only make use of hardware features and code that it provides itself.
In other words, there is not `printf` function, unless the kernel provides its own `<stdio.h>` header and mathing `printf` implementation.
There are no security restrictions, no safeguards, and no debugging mechanisms: there is only what the kernel provides.
***The kernel has complete and absolute power over the machine.***

The start of the entry point is a good place to initialise crucial processor state before entering the high-level kernel.
It is best to minimise the early environment where crucial features are offline, such as floating point instructions and instruction set extensions.
This is also a good place to load the GDT and enable paging.
Any C++ features such as global constructors and exceptions should also be set up here as well.

Once the processor has been initialsed, we can enter the high-level kernel by calling the `kernel_main` function, which will be defined in either C or C++.
For the `call` instruction, the ABI requires the stack to be aligned to 16-bytes, which will then push the return pointer of size 4 bytes.
As the stack was originally aligned to 16-bytes, and we have pushed a multiple of 16 bytes to the stack (and popped 0 bytes), the alignment has been preserved. Thus the call is well defined.

After entering the high-level kernel, we will regain control only when the kernel has finished.
As such, the system will have nothing more to do, so we can put the computer into an infinite loop.
To do this, first disable interrupts.
Interrupts should already be disabled in the bootloader, so this is hypothetically unneccessary.
However, interrupts may at some point be enabled, so it is best to ensure that they are disabled before proceeding.
Once interrupts are disabled, wait for the next interrupt to arrive by halting.
As interrupts are disabled, this will lock the computer.
Finally, jump to the halt instruction if the system ever wakes up, which could happen if there is a non-maskable interrupt or system management mode is used.
Sample code for this process is given below:
```asm
    cli
1:  hlt
    jmp 1b
```

### x86
When the bootloader hands over control, the system will be in 32-bit protected mode, with interrupts and paging **disabled**.
