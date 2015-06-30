section .text

FD_STDIN  equ 0
FD_STDOUT equ 1
FD_STDERR equ 2

; print_err ( s str ) int
print_err:
  mov rsi, [rdi]                       ; The length fields is at the origin
  add rdi, 8                           ; The data is at origin + 8 bytes
  call stderr_write
  ret

; read_str ( buf str, len int ) int
read_str:
  mov r15, rdi

  add rdi, 8                           ; We read into the data field
  call stdin_read

  mov [r15], rax                       ; Write the string length
  ret

; print_int ( v int ) int
print_int:
  mov rsi, INT2STR_BUF + 20            ; String cursor
  mov rcx, 0                           ; Negative flag
  mov r8, 0                            ; String length

  mov byte [rsi], 0x0A                 ; End it with a newline
  dec rsi
  inc r8
  
  cmp rdi, 0                           ; If's a negative number
  jge .positive
  
  mov rcx, 1                           ; Set the negative flag
  neg rdi
  
.positive:
  mov rax, rdi                         ; Move the argument into rax

  .radix_loop:
    mov rdx, 0
    mov rbx, 10
    div rbx                            ; Divide rax, and store the rem in rdx

    add dl, '0'                        ; Turn the remainder into ASCII
    mov byte [rsi], dl                 ; And write it into the string
    dec rsi                            ; Move the string cursor
    inc r8

    cmp rax, 0                         ; If rax is just zero we can stop
    jg .radix_loop

  test rcx, rcx
  jz .skip_negative

  mov byte [rsi], '-'
  dec rsi
  inc r8

.skip_negative:
  inc rsi

  callf stderr_write, rsi, r8          ; Print the string
  ret

; stderr_write ( data *u8, len usize ) int
stderr_write:
  push r11

  mov rax, 1
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDERR
  syscall

  pop r11
  ret

; stdout_write ( data *u8, len usize ) int
stdout_write:
  push r11

  mov rax, 1
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDOUT
  syscall

  pop r11
  ret

; stdin_read ( dest *u8, len usize ) int
stdin_read:
  push r11

  mov rax, 0
  mov rdx, rsi
  mov rsi, rdi
  mov rdi, FD_STDIN
  syscall

  pop r11
  ret

; exit ()
exit:
  mov rax, 60
  syscall

section .bss
INT2STR_BUF resb 20
