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
  callf Vec_pushb, rbp, 0
  callf Vec_pushw, rbp, 0
  callf Vec_pushd, rbp, 0
  callf Vec_pushq, rbp, 0
  callf print_int, [rbp + Vec.length]
  call exit

section .data
section .bss
