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

### How it works

The infection works by using the presence of PT_NOTE segment(s) in most binaries with a ELF header. Changing them doesn't alter the program execution, thus allowing us to change it to a PT_LOAD segment. \
Then, we'll modify the binary to first execute the injected payload. This won't cause any crash because the newly modified PT_LOAD segment will make the binary think that it is part of a regular execution.

Afterwards, we give control back to the normal execution. To do that, we need to jump to the original entry point after our payload is executed.

Overall, these steps are effectively achieved by finding the first PT_NOTE section in the program headers of the file, then:

- changing P_TYPE from PT_NOTE (4) to PT_LOAD (1)
- changing P_FLAGS to Execute|Read (5)
- changing P_OFFSET to the end of the file
- changing P_VADDR to 0xF0000 + the size of the file
- adding the size of the payload to P_FILESZ and P_MEMSZ
- changing P_ALIGN to 0x1000 (this is optional as it will still work without it)
- changing E_ENTRY to the new P_VADDR
- appending a payload at the end of the file that jumps back to the original E_ENTRY after execution

Arguments passed to the infected binary should still work during the normal execution. \
Additionnaly, the infector adds a 7 bytes signature 8 bytes into the ELF header to mark it as infected already.

### Challenges encountered

Multiple challenges were encountered while trying to develop this program. Below is a non-exhaustive list with the solutions if applicable.

- Around the start it was time-consuming checking if the header was successfully modified or not, but I ended up abusing `sha256sum` to do a first check, before checking more thoroughly.
- When I was trying to append a payload it would not execute. I tried tracing execution with gdb but I couldn't place breakpoints inside the payload.
- At some point I was stuck not knowing what to append at the end of the file but I ended up going for raw bytecode array. I would write the payload in a test `.s` file, compile it, and run `objdump -d -M x86-64` on it to copy the bytecode array.
- I got stuck trying to understand how to properly jump at the end of the payload. At first I tried doing `mov rax, [old_e_entry]` followed by `FF E0` (`jmp rax`) but it was not working. \
I ended up using `E9` (relative `jmp` instead of absolute) and manually computed the destination address.
- The first payload I used to test my program was one executing `/bin/sh`, but I couldn't know if it was successfully resuming the normal execution afterward. \
When I tried using another payload it would crash with a segmentation fault, meaning my `jmp` at the end was still broken. \
- `b _start` in gdb was not helping because I couldn't break during the payload execution. To solve this, I had to purposefully write broken bytecode to provoke a crash inside the payload, that would let gdb show the lines around the crash. \
This helped me confirm that my `jmp` was indeed broken (both when I tried absolute at first, then relative).
- Even when I got the right `jmp` at the end of the payload, the program would resume normal execution, then crash at the first `pop rsi` or at the last instruction. This was likely due to the payload messing too much with the registers and the stack. \
To fix this, I pushed every used register and gave the payload some space by substracting 0x1000 to `rsp`, before adding it back right before popping the registers.
- I tried to test the program on Debian 12. `/tmp/outfile` was created but was empty. The binary was still executing normally without crashing. This was probably due to open, read, or write permission issues and another payload not requiring such permission should work. I tried using sudo but this didn't make any difference.

## References

- [guitmz/midrashim](https://github.com/guitmz/midrashim)
- [PT_NOTE to PT_LOAD Injection in ELF](https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf/)