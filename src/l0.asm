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
  sub rsp, Vec_size
  callf new_Vec, rbp, 4
  callf Vec_pushb, rbp, 'a'
  callf Vec_pushb, rbp, 'b'
  callf Vec_pushb, rbp, 'c'
  callf Vec_pushb, rbp, 'd'
  callf stdout_write, [rbp + Vec.data], [rbp + Vec.length]
  ; Double the size
  callf Vec_reallocate, rbp, 8
  callf stdout_write, [rbp + Vec.data], [rbp + Vec.length]
  call exit

section .data
section .bss
