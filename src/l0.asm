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
  callf Vec_pushb, rbp, '<'
  callf Vec_pushw, rbp, 0x2d2d
  callf Vec_pushd, rbp, 0x2d2d2d2d
  callf Vec_pushq, rbp, 0x3e2d2d2d2d2d2d2d
  callf stdout_write, [rbp + Vec.data], [rbp + Vec.length]
  callf Vec_lookupb, rbp, 0
  and rax, 0xff
  callf print_int, rax
  callf Vec_lookupw, rbp, 1
  and rax, 0xffff
  callf print_int, rax
  callf Vec_lookupd, rbp, 3
  callf print_int, rax
  and rax, 0xffffffff
  callf Vec_lookupq, rbp, 7
  callf print_int, rax
  call exit

section .data
section .bss
