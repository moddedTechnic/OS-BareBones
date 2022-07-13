
# Assembly

## Constructs

### `.align X`
Aligns to an `X`-byte boundary.

### `.section NAME`
Creates a new section with the name `NAME`, which should be one of:

| Name         | Purpose                     |
| ------------ | --------------------------- |
| `.multiboot` | makes a multiboot header    |
| `.bss`       | creates a space for a stack |

### `.set NAME, VALUE`
Sets a constant with the name `NAME` to have the value `VALUE`

### `.skip X`
Leave `X` bytes when buiding the executable.


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
// Align if necessary
stack_bottom:
.skip STACK_SIZE
stack_top:
```

#### x86

On x86 architechture, the stack grows downwards.

According to the System V ABI standard and de-facto extensions, the stack should be 16-byte aligned.
The compiler will assume that the stack is properly aligned.
Failure to do so will result in undefined behaviour.
