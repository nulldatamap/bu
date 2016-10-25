section .text

; Calling convension:
; Ints/poitners: RDI, RSI, RDX, RCX, R8, and R9
; Floats: XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7

FD_STDIN  equ 0
FD_STDOUT equ 1
FD_STDERR equ 2

; raw_str_cmp ( alen int, aadr *u8, blen int, badr *u8 ) bool
raw_str_cmp:
  ; USED:
  ;  rdi, rsi, rdx, rcx
  push rbx

  cmp rdi, rdx                         ; Compare the strings' lengths
  jne .false

  xor rbx, rbx                         ; Set the index to 0

.cmp_loop:
  mov al, [rcx + rbx]                  ; Loads B's char at the index
  cmp byte [rsi + rbx], al             ; And compare it with A's char
  jne .false                           ; Return fasle if they're not equal

  inc rbx                              ; Otherwise get the next index
  cmp rbx, rdi                         
  jne .cmp_loop                        ; Loop again if there's more
                                       ; If not:
  mov rax, 1                           ; return true

  pop rbx
  ret

.false:
  xor rax, rax

  pop rbx
  ret

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

; write_err_nl () void
write_err_nl:
  mov rdi, MSG_NEWLINE
  call print_err
  ret

; print_int ( v int ) int
print_int:
  mov rsi, int2str_buf + 20            ; String cursor
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

; str2int ( s *str ) int
str2int:
  ; Needed varibles:
  ;  Accumilator: rcx
  ;  Current char: rax
  ;  String index: rdi
  ;  String length: rsi
  ;  Minus flag: r8
  
  ; Load the string length and setup the starting index as the end of the string
  mov rsi, [rdi]
  lea rdi, [rdi + 8]
  add rsi, rdi
  xor r8, r8
  xor rcx, rcx

  ; Check if there's a minus sign
  xor rax, rax
  mov al, [rdi]
  cmp rax, '-'
  jne .digit_loop
  mov r8, 1
  inc rdi

.digit_loop:
  xor rax, rax
  mov al, [rdi]
  sub rax, '0'
  add rcx, rax
  inc rdi
  cmp rdi, rsi
  je .done
  mov rax, rcx
  mov r9, 10
  mul r9
  mov rcx, rax
  jmp .digit_loop
  ; Once done, apply the minus sign if need be 
.done:
  mov rax, rcx
  test r8, r8
  jz .skip_negative
  neg rax
.skip_negative:
  ret

; print_hex ( v int ) int
print_hex:
  mov byte [int2str_buf_nl], `\n`
  mov r8, int2str_buf + 19
  mov byte [r8], '0'
  mov r9, rdi
  mov rcx, 0
  mov rsi, 2
  cmp r9, 0
  jne .loop_begin
  dec r8
  inc rsi
  jmp .loop_end

.loop_begin:
  mov rax, r9
  shr rax, cl
  cmp rax, 0
  je .loop_end

  and rax, 0xF
  
  cmp rax, 0x09
  jg .write_letter

  add rax, '0'
  jmp .write_to_buffer

.write_letter:
  add rax, 'a' - 10

.write_to_buffer:
  mov [r8], al
  dec r8
  inc rsi

  add rcx, 4
  cmp rcx, 64
  jne .loop_begin

.loop_end:
  sub r8, 1
  add rsi, 1
  mov word [r8], '0x'
  
  mov rdi, r8
  call stdout_write
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

section .data
str_const SEARCH, "Got so far: "
str_const MSG_NEWLINE, `\n`

section .bss
align 8
int2str_buf    resb 20
int2str_buf_nl resb 1

