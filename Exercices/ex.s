section .data
    filename db "uppercase", 0
    elf db 0x7F, 'E', 'L', 'F'
    buffer times 4 db 0
    len equ 4

    not_elf_msg db "This file does not have a ELF header.", 10
    not_elf_len equ $ - not_elf_msg

section .text
    global _start

_start:
    ; Open the file
    mov rax, 2
    mov rdi, filename
    mov rsi, 0          ; O_RDONLY (read-only)
    syscall
    mov rdi, rax        ; file descriptor

    ; Read the file contents
    mov rax, 0          
    mov rsi, buffer
    mov rdx, len
    syscall

    ; Check if it has a ELF header
    mov rdi, buffer
    mov ri, elf        
    mov rcx, 4         
    repe cmpsb          
    jne not_elf

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
    ; Close the file
    mov rax, 3
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall