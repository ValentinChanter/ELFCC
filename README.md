<p align="center">
    <h3 align="center">ELFCC</h3>
</p>

<p align="center">PT_NOTE to PT_LOAD based ELF infector</p>

<br/>

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Requirements](#requirements)
- [Usage](#usage)
- [How it works \& challenges encountered](#how-it-works--challenges-encountered)
  - [How it works](#how-it-works)
  - [Challenges encountered](#challenges-encountered)
- [References](#references)

## Introduction

This program allows the user to infect a file with a ELF header and at least one PT_NOTE segment. \
It copies the content of `/etc/passwd` into `/tmp/outfile` and resumes the normal execution of the infected file.

The user must have read/write permission on the file to infect or the program will consider that it is not ELF. \
A file that is already infected cannot be infected again.

## Requirements

This program was tested using nasm version 2.16.01 on Ubuntu 24.04 and nasm version 2.15.05 on Linux Mint 21.2.

## Usage

1. Clone this repo and access it

    ```bash
    git clone https://github.com/ValentinChanter/ELFCC
    cd ELFCC
    ```

2. Compile the assembly program

    ```bash
    nasm -f elf64 -o elf_infector.o elf_infector.s && ld -g -o elf_infector elf_infector.o
    ```

3. Add execution permission on the file if needed

    ```bash
    chmod u+x ./elf_infector
    ```

4. Infect a file with a ELF header and at least one PT_NOTE segment.

    ```bash
    ./elf_infector <file_to_infect>
    ```

## How it works & challenges encountered

### <ins>If you want a shorter, more concise version of this section, see [10a294a](https://github.com/ValentinChanter/ELFCC/tree/10a294aa62796755e92fc1aee161b181dcf2815c?tab=readme-ov-file#how-it-works--challenges-encountered)</ins>

### How it works

Most binaries in Unix systems have an ELF header. This header contains headers and segments, the latter being described in the Program Header Table.

A `PT_NOTE` segment holds metadata on the file, which can be changed to a `PT_LOAD` segment without altering the execution of the program by changing `P_TYPE` to from `5` to `1`. This is the base of our infection. \
The additional section will require at least execution and read permission, which can be done by changing the segment's `P_FLAGS` to `5`. \
We also need to specify where the segment starts, by changing its `P_OFFSET` to the end of the file, which will be where the start of our payload is. \
We need to set `P_VADDR` to an address far from the end of the file so the normal execution still has room to execute without overlapping on our payload.

Adding the size of the payload to `P_FILESZ` and `P_MEMSZ` is also very important because they need to specify the new size of the segment in the file and in the memory accordingly. \
`P_ALIGN` is changed to `0x1000` in the code but this is not necessary and simply to mimic the behavior of other `PT_LOAD` segments.

The ELF header also includes some fields like `E_ENTRY`, which determines where the execution begins. We can modify this and write the address of the start of our payload to execute it beforehand. \
This won't cause any crash because the newly modified PT_LOAD segment will make the binary think that it is part of a regular execution. \
In the end, we need to append the payload we want to inject at the end of the file, and not forget to patch it to jump at the initial `E_ENTRY` to resume a normal execution.

Arguments passed to the infected binary should still work during the normal execution. \
Additionnaly, the infector adds a 7 bytes signature 8 bytes into the ELF header to mark it as infected already.

### Challenges encountered

Multiple challenges were encountered while trying to develop this program.

Around the start it was time-consuming checking if the header was successfully modified or not, but I ended up abusing `sha256sum` to do a first check, before checking more thoroughly. After I could successfully check that, I tried writing the payload at the end of the file but it would not execute. I tried tracing execution with gdb but I couldn't place breakpoints inside the payload.

Besides, I didn't even know what to write in the payload but I eventually chose to write the payload in the form of a raw bytecode array. I would write the payload in a test `.s` file, compile it, and run `objdump -d -M x86-64` on it to copy the bytecode array. I knew I needed to jump to the original `E_ENTRY` at the end of the payload but I couldn't understand how to properly do it. At first I tried doing `mov rax, [old_e_entry]` followed by `FF E0` (`jmp rax`) but it was not working. \
I ended up using `E9` (relative `jmp` instead of absolute) and manually computed the destination address by removing the offset at which the `jmp` instruction was in the payload, then removing `P_VADDR` to come back to the "start" of the file (virtually), then adding `E_ENTRY` so it would point there relative to the `jmp` instruction.

The first payload I used to test my program was one executing `/bin/sh`, but I couldn't know if it was successfully resuming the normal execution afterward. \
When I tried using another payload it would crash with a segmentation fault, meaning my `jmp` at the end was still broken.

`b _start` in gdb was not helping because I couldn't break during the payload execution. To solve this, I had to purposefully write broken bytecode to provoke a crash inside the payload, that would let gdb show the lines around the crash. \
This helped me confirm that my `jmp` was indeed broken (both when I tried absolute at first, then relative). Even when I got the right `jmp` at the end of the payload, the program would resume normal execution, then crash at the first `pop rsi` or at the last instruction. This was likely due to the payload messing too much with the registers and the stack. \
To fix this, I pushed every used register and gave the payload some space by substracting 0x1000 to `rsp`, before adding it back right before popping the registers.

I tried to test the program on Debian 12. `/tmp/outfile` was created but was empty. The binary was still executing normally without crashing. This was probably due to open, read, or write permission issues and another payload not requiring such permission should work. I tried using sudo but this didn't make any difference.

## References

- [guitmz/midrashim](https://github.com/guitmz/midrashim)
- [PT_NOTE to PT_LOAD Injection in ELF](https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf/)
