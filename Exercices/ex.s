%include "print_hex.asm"

section .data
    flags dq 2      ; 0_RDWR
    mode dq 0666    ; r/w permissions for user, group and others

    ; File to open
    filename db "adfzdaz", 0
    
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

section .bss
    fd resq 1   ; Reserve space for the file descriptor

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
    ; Display a message
    mov rax, 1          
    mov rdi, 1
    mov rsi, elf_msg
    mov rdx, elf_len
    syscall

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