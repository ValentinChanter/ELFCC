; Using https://gist.github.com/kthompson/957c635d84b7813945aa9bb649f039b9

section .text
global print_string

print_string:
  ; Save registers manually
  push rax
  push rbx

string_loop:
  mov al, [rbx]        ; Load the byte at rbx into al
  cmp al, 0            ; Check if it's the null terminator
  je done_string       ; If yes, exit loop

  mov rax, 1           ; syscall number for sys_write
  mov rdi, 1           ; file descriptor 1 (stdout)
  mov rsi, rbx         ; address of character to print
  mov rdx, 1           ; length is 1 byte
  syscall

  inc rbx              ; Move to the next character
  jmp string_loop      ; Repeat the loop

done_string:
  ; Restore registers manually
  pop rbx
  pop rax
  ret
