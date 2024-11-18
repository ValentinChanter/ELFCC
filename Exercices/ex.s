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
    ei_class_msg db "ei_class = ", 0
    ei_class_msg_len equ $ - ei_class_msg
    ei_class_len equ 1
    ei_data_msg db "ei_data = ", 0
    ei_data_msg_len equ $ - ei_data_msg
    ei_data_len equ 1
    ei_version_msg db "ei_version = ", 0
    ei_version_msg_len equ $ - ei_version_msg
    ei_version_len equ 1
    ei_osabi_msg db "ei_osabi = ", 0
    ei_osabi_msg_len equ $ - ei_osabi_msg
    ei_osabi_len equ 1
    ei_osabi_version_msg db "ei_osabi_version = ", 0
    ei_osabi_version_msg_len equ $ - ei_osabi_version_msg
    ei_osabi_version_len equ 2
    e_type_msg db "e_type = ", 0
    e_type_msg_len equ $ - e_type_msg
    e_type_len equ 2
    e_machine_msg db "e_machine = ", 0
    e_machine_msg_len equ $ - e_machine_msg
    e_machine_len equ 2
    e_version_msg db "e_version = ", 0
    e_version_msg_len equ $ - e_version_msg
    e_version_len equ 4
    e_entry_msg db "e_entry = ", 0
    e_entry_msg_len equ $ - e_entry_msg
    e_entry_len equ 8
    e_phoff_msg db "e_phoff = ", 0
    e_phoff_msg_len equ $ - e_phoff_msg
    e_phoff_len equ 8
    e_shoff_msg db "e_shoff = ", 0
    e_shoff_msg_len equ $ - e_shoff_msg
    e_shoff_len equ 8
    e_flags_msg db "e_flags = ", 0
    e_flags_msg_len equ $ - e_flags_msg
    e_flags_len equ 4
    e_ehsize_msg db "e_ehsize = ", 0
    e_ehsize_msg_len equ $ - e_ehsize_msg
    e_ehsize_len equ 2
    e_phentsize_msg db "e_phentsize = ", 0
    e_phentsize_msg_len equ $ - e_phentsize_msg
    e_phentsize_len equ 2
    e_phnum_msg db "e_phnum = ", 0
    e_phnum_msg_len equ $ - e_phnum_msg
    e_phnum_len equ 2
    e_shentsize_msg db "e_shentsize = ", 0
    e_shentsize_msg_len equ $ - e_shentsize_msg
    e_shentsize_len equ 2
    e_shnum_msg db "e_shnum = ", 0
    e_shnum_msg_len equ $ - e_shnum_msg
    e_shnum_len equ 2
    e_shstrndx_msg db "e_shstrndx = ", 0
    e_shstrndx_msg_len equ $ - e_shstrndx_msg
    e_shstrndx_len equ 2

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

    jmp parse_elf_header

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

    add [offset_counter], r10

    mov rsi, buffer             ; Set rsi to the beginning
    add rsi, rbx                ; Added offset when using print_field to print program header fields
    add rsi, [offset_counter]   ; Get the field

    cmp r8, 2
    je print_field_2

    cmp r8, 4
    je print_field_4

    cmp r8, 8
    je print_field_8

    jmp print_field_16

; Depending on the size of the field, we move the hex value to the register of the corresponding size
print_field_2:
    mov dl, [rsi]
    jmp print_field_end

print_field_4:
    mov dx, [rsi]
    jmp print_field_end

print_field_8:
    mov edx, [rsi]
    jmp print_field_end

print_field_16:
    mov rdx, [rsi] 
    jmp print_field_end

print_field_end:
    call print_hex
    call print_newline

    ret

parse_elf_header:
    xor rbx, rbx
    mov rcx, 4
    mov [offset_counter], rcx

    ; Display ei_class
    mov rsi, ei_class_msg
    mov rdx, ei_class_msg_len
    xor r10, r10 ; Call with an offset of 0
    mov r8, ei_class_len * 2
    call print_field

    ; Display ei_data
    mov rsi, ei_data_msg
    mov rdx, ei_data_msg_len
    mov r10, ei_class_len
    mov r8, ei_data_len * 2
    call print_field

    ; Display ei_version
    mov rsi, ei_version_msg
    mov rdx, ei_version_msg_len
    mov r10, ei_data_len
    mov r8, ei_version_len * 2
    call print_field

    ; Display ei_osabi
    mov rsi, ei_osabi_msg
    mov rdx, ei_osabi_msg_len
    mov r10, ei_version_len
    mov r8, ei_osabi_len * 2
    call print_field

    ; Display ei_osabi_version
    mov rsi, ei_osabi_version_msg
    mov rdx, ei_osabi_version_msg_len
    mov r10, ei_osabi_len
    mov r8, ei_osabi_version_len * 2
    call print_field

    mov rcx, [offset_counter]
    add rcx, 6         ; ei_osabiver is at 0x08 and 2 long but e_type doesn't start before an offset of 0x10
    mov [offset_counter], rcx

    ; Display e_type
    mov rsi, e_type_msg
    mov rdx, e_type_msg_len
    mov r10, ei_osabi_version_len
    mov r8, e_type_len * 2
    call print_field

    ; Display e_machine
    mov rsi, e_machine_msg
    mov rdx, e_machine_msg_len
    mov r10, e_type_len
    mov r8, e_machine_len * 2
    call print_field

    ; Display e_version
    mov rsi, e_version_msg
    mov rdx, e_version_msg_len
    mov r10, e_machine_len
    mov r8, e_version_len * 2
    call print_field

    ; Display e_entry
    mov rsi, e_entry_msg
    mov rdx, e_entry_msg_len
    mov r10, e_version_len
    mov r8, e_entry_len * 2
    call print_field

    ; Display e_phoff
    mov rsi, e_phoff_msg
    mov rdx, e_phoff_msg_len
    mov r10, e_entry_len
    mov r8, e_phoff_len * 2
    call print_field

    ; Display e_shoff
    mov rsi, e_shoff_msg
    mov rdx, e_shoff_msg_len
    mov r10, e_phoff_len
    mov r8, e_shoff_len * 2
    call print_field

    ; Display e_flags
    mov rsi, e_flags_msg
    mov rdx, e_flags_msg_len
    mov r10, e_shoff_len
    mov r8, e_flags_len * 2
    call print_field

    ; Display e_ehsize
    mov rsi, e_ehsize_msg
    mov rdx, e_ehsize_msg_len
    mov r10, e_flags_len
    mov r8, e_ehsize_len * 2
    call print_field

    ; Display e_phentsize
    mov rsi, e_phentsize_msg
    mov rdx, e_phentsize_msg_len
    mov r10, e_ehsize_len
    mov r8, e_phentsize_len * 2
    call print_field

    ; Display e_phnum
    mov rsi, e_phnum_msg
    mov rdx, e_phnum_msg_len
    mov r10, e_phentsize_len
    mov r8, e_phnum_len * 2
    call print_field

    ; Display e_shentsize
    mov rsi, e_shentsize_msg
    mov rdx, e_shentsize_msg_len
    mov r10, e_phnum_len
    mov r8, e_shentsize_len * 2
    call print_field

    ; Display e_shnum
    mov rsi, e_shnum_msg
    mov rdx, e_shnum_msg_len
    mov r10, e_shentsize_len
    mov r8, e_shnum_len * 2
    call print_field

    ; Display e_shstrndx
    mov rsi, e_shstrndx_msg
    mov rdx, e_shstrndx_msg_len
    mov r10, e_shnum_len
    mov r8, e_shstrndx_len * 2
    call print_field

    call print_newline

    jmp retrieve_ph_info

retrieve_ph_info:
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