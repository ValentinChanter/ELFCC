section .data
    filename db "test.txt", 0
    buffer times 32 db 0
    len equ 32

section .text
    global _start

_start:
    ; sys_open
    mov rax, 2
    mov rdi, filename
    mov rsi, 0          ; O_RDONLY (read-only)
    syscall
    mov rdi, rax        ; file descriptor

    ; sys_read
    mov rax, 0          
    mov rsi, buffer
    mov rdx, len
    syscall

    ; sys_write
    mov rax, 1          
    mov rdi, 1
    mov rsi, buffer
    mov rdx, len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall