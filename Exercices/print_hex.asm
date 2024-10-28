; Using https://gist.github.com/kthompson/957c635d84b7813945aa9bb649f039b9

section .data
HEX_OUT: db '0x0000000000000000', 0  ; Buffer for 16 hex chars + null terminator

section .text
global print_hex

print_hex:
  ; Save registers manually
  push rax
  push rbx
  push rcx
  push rdx

  mov rcx, 16          ; We want to print 16 characters (64 bits, 4 bits per char)

char_loop:
  dec rcx              ; Decrement the counter

  mov rax, rdx         ; Copy rdx into rax to mask it
  shr rdx, 4           ; Shift rdx 4 bits to the right
  and rax, 0xF         ; Mask to get the last 4 bits

  mov rbx, HEX_OUT     ; Set rbx to the memory address of the output string
  add rbx, 2           ; Skip the '0x' prefix
  add rbx, rcx         ; Position rbx to the correct character based on the counter

  cmp rax, 0xA         ; Check if it's a letter or number
  jl set_number        ; If it's a number, go to set_number
  add al, 0x37         ; Convert to ASCII 'A'-'F'
  jmp set_character

set_number:
  add al, 0x30         ; Convert to ASCII '0'-'9'

set_character:
  mov [rbx], al        ; Store the character in HEX_OUT

  cmp rcx, 0           ; Check if we're done
  je print_hex_done
  jmp char_loop

print_hex_done:
  mov rsi, HEX_OUT     ; Set up for sys_write to print HEX_OUT
  mov rax, 1           ; syscall number for sys_write
  mov rdi, 1           ; file descriptor 1 (stdout)
  mov rdx, 18          ; Length of '0x' + 16 hex characters + null terminator
  syscall

  ; Restore registers manually
  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret
