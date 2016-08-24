; Buttom Up
; Level 0, assembly.
; Parses and compiles l1
%include "macros.asm"
%include "io.asm"
%include "mem.asm"
%include "vec.asm"
%include "lex.asm"

section .text

global _start
_start:
  call init_malloc
  call lex
  mov rbp, rsp
  lea r12, [rbp + Vec_size]
  sub rsp, Vec_size * 2
  callf new_Vec, rbp, 4
  callf Vec_pushq, rbp, "!(owwo)!"

  callf new_Vec, r12, 8
  callf Vec_pushq, r12, ">:^((((("

  callf Vec_concat, rbp, r12
  callf stdout_write, [rbp + Vec.data], [rbp + Vec.length]
  call exit

section .data
test_data db " <---"

section .bss
