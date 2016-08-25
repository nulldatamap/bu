section .text

struc Vec
  .data     resq 1
  .length   resq 1
  .capacity resq 1
endstruc

; new_Vec ( vec *Vec, capacity int ) int
new_Vec:
  push r13
  push r14

  mov r13, rdi
  mov r14, rsi
  callf malloc, r14
  mov [r13 + Vec.data], rax
  mov qword [r13 + Vec.length], 0
  mov [r13 + Vec.capacity], r14
  
  pop r14
  pop r13
  ret

; Vec_reallocate ( vec *Vec, capacity int )
Vec_reallocate:
  push r12
  push r13
  push r14
  ; Free the old allocation
  mov r13, rdi
  mov r14, rsi
  callf free, [r13 + Vec.data]
  ; If the length is greater than the new capacity, shorten it to the capacity
  mov rax, [r13 + Vec.length]
  cmp rax, r14
  jbe .skip_length_adjust

  mov [r13 + Vec.length], r14

.skip_length_adjust:
  ; Allocate the new data block
  callf malloc, r14
  ; Store the old data location and write the data field and the capaty field
  mov r12, [r13 + Vec.data]
  mov [r13 + Vec.data], rax
  mov [r13 + Vec.capacity], r14
  ; Now copy over the contents
  mov rcx, [r13 + Vec.length]
  mov rsi, r12
  mov rdi, rax
  rep movsb

  pop r14
  pop r13
  pop r12
  ret

; Vec_resize ( vec *Vec, int length ) ptr
Vec_resize:
  push r12
  push r13

  mov r12, rdi
  mov r13, rsi

  mov rax, [r12 + Vec.capacity]

  cmp r13, rax
  jbe .skip_reallocation

  ; Keep mutiplying by two until we can fit it
  xor rdx, rdx
.bigger:
  mov rcx, 2
  mul rcx
  cmp r13, rax
  ja .bigger

  callf Vec_reallocate, rdi, rax

.skip_reallocation:
  mov [r12 + Vec.length], r13
  
  pop r13
  pop r12
  ret

%macro _Vec_push_ 3
  push r12
  push r13
  push r14

  mov r12, rdi
  mov %2, %1
  
  mov rsi, [r12 + Vec.length]
  mov r14, rsi
  add rsi, %3

  call Vec_resize

  add r14, [r12 + Vec.data]
  mov [r14], %2

  pop r14
  pop r13
  pop r12
  ret
%endmacro

; Vec_pushb ( vec *Vec, byte val ) ptr
Vec_pushb:
  _Vec_push_ sil, r13b, 1

; Vec_pushw ( vec *Vec, word val ) ptr
Vec_pushw:
  _Vec_push_ si, r13w, 2

; Vec_pushd ( vec *Vec, byte val ) ptr
Vec_pushd:
  _Vec_push_ esi, r13d, 4

; Vec_pushd ( vec *Vec, byte val ) ptr
Vec_pushq:
  _Vec_push_ rsi, r13, 8

; _Vec_check_bounds ( vec *Vec, index int )
_Vec_check_bounds:
  cmp rsi, [rdi + Vec.length]
  jb .in_bounds
  ; Where out of bounds!
  callf print_err, OUT_OF_BOUNDS
  call exit

.in_bounds:
  ret

; Vec_lookupb ( vec *Vec, index int ) byte 
Vec_lookupb:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov al, [rax + rsi]
  ret

; Vec_lookupw ( vec *Vec, index int ) word
Vec_lookupw:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov ax, [rax + rsi]
  ret

; Vec_lookupd ( vec *Vec, index int ) dword
Vec_lookupd:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov eax, [rax + rsi]
  ret

; Vec_lookupq ( vec *Vec, index int ) qword
Vec_lookupq:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov rax, [rax + rsi]
  ret

; Vec_setb ( vec *Vec, index int, val byte )
Vec_setb:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov [rax + rsi], dl
  ret

; Vec_setw ( vec *Vec, index int, val word )
Vec_setw:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov [rax + rsi], dx
  ret

; Vec_setd ( vec *Vec, index int, val dword )
Vec_setd:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov [rax + rsi], edx
  ret

; Vec_setq ( vec *Vec, index int, val qword )
Vec_setq:
  call _Vec_check_bounds
  mov rax, [rdi + Vec.data]
  mov [rax + rsi], rdx
  ret

; Vec_push_all ( vec *Vec, data ptr, length int )
Vec_push_all:
  push r12
  push r13
  push r14

  mov r12, rdi
  mov r13, rsi
  mov r14, [r12 + Vec.length]
  ; Resize to vec.length + length
  add rdx, r14
  mov rsi, rdx
  call Vec_resize

  ; Copy over the contents
  mov rcx, r14
  mov rsi, r13
  mov rdi, [r12 + Vec.data]
  add rdi, r14
  rep movsb

  pop r14
  pop r13
  pop r12
  ret

; Vec_concat ( a *Vec, b *Vec )
Vec_concat:
  mov rax, rsi
  mov rsi, [rax + Vec.data]
  mov rdx, [rax + Vec.length]
  call Vec_push_all
  ret

section .data
str_const OUT_OF_BOUNDS, `Vector access out of bounds!\n`
