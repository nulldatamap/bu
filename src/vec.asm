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

  mov rcx, 2
  xor rdx, rdx
  mul rcx
  callf Vec_reallocate, rdi, rax

.skip_reallocation:
  mov [r12 + Vec.length], r13
  
  pop r13
  pop r12
  ret


; Vec_push ( vec *Vec, byte val ) ptr
Vec_pushb:
  push r12
  push r13
  push r14

  mov r12, rdi
  mov r13b, sil
  
  mov r14, [r12 + Vec.data]
  mov rsi, [r12 + Vec.length]
  lea r14, [r14 + rsi]
  inc rsi

  call Vec_resize
  
  mov [r14], r13b

  pop r14
  pop r13
  pop r12
  ret
