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

; Vec_push ( vec *Vec, byte val ) ptr
Vec_pushb:
  push r12
  push r13
  push r14

  mov r13, rdi
  mov r14, rsi
  mov rax, [r13 + Vec.length]
  inc rax
  mov r12, [r13 + Vec.capacity]
  cmp rax, r12
  jbe .skip_allocate

  ; Reallocate with capacity * 2 as the new capacity
  mov rax, 2
  xor rdx, rdx
  mul r12
  callf Vec_reallocate, r13, rax

.skip_allocate:
  ; Write the byte
  mov rax, [rdi + Vec.length]
  mov rdx, [rdi + Vec.data]
  mov [rdx + rax], r14b
  ; and increment the size
  inc qword [rdi + Vec.length]
  
  pop r14
  pop r13
  pop r12
  ret
