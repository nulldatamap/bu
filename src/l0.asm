; Buttom Up
; Level 0, assembly.
; Parses and compiles l1
%include "macros.asm"
%include "io.asm"
%include "mem.asm"
%include "vec.asm"
%include "lex.asm"
%include "parse.asm"

section .text

global _start
_start:
  call init_malloc
  call lex
  mov rdi, rax
  mov rsi, rdx
  call parse
  callf print_hex, rax
  call exit

section .bss
