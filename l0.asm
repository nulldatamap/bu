; Buttom Up
; Level 0, assembly.
; Parses and compiles l1
%include "macros.asm"
%include "io.asm"
%include "lex.asm"

section .text

global _start
_start:
  call lex
  mov rdi, rax                         ; The return code is the one of lex()
  call exit

section .data
section .bss
