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
  sub rsp, Vec_size * 2
  callf new_Vec, rbp, 4
  callf Vec_resize, rbp, 24
  callf print_int, [rbp + Vec.capacity]
  call exit

section .data
test_data db " <---"

section .bss
