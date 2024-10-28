%include "print_hex.asm"

section .data
    flags dq 2      ; 0_RDWR
    mode dq 0666    ; r/w permissions for user, group and others

    ; File to open
    filename db "uppercase", 0
    
    ; Buffer to retrieve the ELF header
    buffer_len equ 640
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


    newline db 10
    ; ELF header fields


    ; Program header fields
    p_type_msg db "p_type = ", 0
    p_type_msg_len equ $ - p_type_msg
    p_type_len equ 4
    p_flags_msg db "p_flags = ", 0
    p_flags_msg_len equ $ - p_flags_msg
    p_flags_len equ 4
    p_offset_msg db "p_offset = ", 0
    p_offset_msg_len equ $ - p_offset_msg
    p_offset_len equ 8
    p_vaddr_msg db "p_vaddr = ", 0
    p_vaddr_msg_len equ $ - p_vaddr_msg
    p_vaddr_len equ 8
    p_paddr_msg db "p_paddr = ", 0
    p_paddr_msg_len equ $ - p_paddr_msg
    p_paddr_len equ 8
    p_filesz_msg db "p_filesz = ", 0
    p_filesz_msg_len equ $ - p_filesz_msg
    p_filesz_len equ 8
    p_memsz_msg db "p_memsz = ", 0
    p_memsz_msg_len equ $ - p_memsz_msg
    p_memsz_len equ 8
    p_align_msg db "p_align = ", 0
    p_align_msg_len equ $ - p_align_msg
    p_align_len equ 8

section .bss
    fd resq 1   
    ph_offset resq 1
    ph_entry_size resq 1
    ph_num resq 1
    loop_counter resq 1
    offset_counter resq 1

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
    mov rsi, elfbuf
    mov rdx, elfbuf_len
    syscall

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
    mov rsi, elfbuf
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

    jmp parse_program_header

parse_program_header:
    ; Retrieve program header information
    mov rsi, buffer
    add rsi, 32         ; Move to the e_phoff field (32 bytes offset in the ELF header)
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

    mov rbx, [ph_offset]
    jmp print_program_header

print_newline:
    ; Display a newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

    ret

; Print a program header field
; Move the newly added offset to r10, the length of the hex value to r8, the message to display in rsi and its length in rdx before calling
print_field:
    mov rax, 1
    mov rdi, 1
    syscall

    mov rcx, [offset_counter]
    add rcx, r10
    mov [offset_counter], rcx

    mov rsi, buffer             ; Set rsi to the beginning
    add rsi, rbx                ; Add the offset to get to the first program header
    add rsi, [offset_counter]   ; Get the field

    cmp r8, 8
    je print_field_8
    jmp print_field_16

print_field_8:
    mov edx, [rsi]              ; Move hex value to rdx
    jmp print_field_end

print_field_16:
    mov rdx, [rsi]              ; Move hex value to rdx
    jmp print_field_end

print_field_end:
    call print_hex
    call print_newline

    ret

print_program_header:
    mov [loop_counter], rcx
    xor rcx, rcx
    mov [offset_counter], rcx
    
    ; Display p_type
    mov rsi, p_type_msg
    mov rdx, p_type_msg_len
    xor r10, r10 ; Call with an offset of 0
    mov r8, p_type_len * 2
    call print_field

    ; Display p_flags
    mov rsi, p_flags_msg
    mov rdx, p_flags_msg_len
    mov r10, p_type_len
    mov r8, p_flags_len * 2
    call print_field

    ; Display p_offset
    mov rsi, p_offset_msg
    mov rdx, p_offset_msg_len
    mov r10, p_flags_len
    mov r8, p_offset_len * 2
    call print_field

    ; Display p_vaddr
    mov rsi, p_vaddr_msg
    mov rdx, p_vaddr_msg_len
    mov r10, p_offset_len
    mov r8, p_vaddr_len * 2
    call print_field

    ; Display p_paddr
    mov rsi, p_paddr_msg
    mov rdx, p_paddr_msg_len
    mov r10, p_vaddr_len
    mov r8, p_paddr_len * 2
    call print_field

    ; Display p_filesz
    mov rsi, p_filesz_msg
    mov rdx, p_filesz_msg_len
    mov r10, p_paddr_len
    mov r8, p_filesz_len * 2
    call print_field

    ; Display p_memsz
    mov rsi, p_memsz_msg
    mov rdx, p_memsz_msg_len
    mov r10, p_filesz_len
    mov r8, p_memsz_len * 2
    call print_field

    ; Display p_align
    mov rsi, p_align_msg
    mov rdx, p_align_msg_len
    mov r10, p_memsz_len
    mov r8, p_align_len * 2
    call print_field

    call print_newline

    add rbx, [ph_entry_size]
    mov rcx, [loop_counter]
    dec rcx
    mov [loop_counter], rcx
    jnz print_program_header

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