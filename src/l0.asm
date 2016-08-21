; Buttom Up
; Level 0, assembly.
; Parses and compiles l1
%include "macros.asm"
%include "io.asm"
%include "mem.asm"
%include "lex.asm"

section .text

global _start
_start:
  call lex
  callf print_err, DBG_000
  mov rdi, rax                         ; The return code is the one of lex()
  call init_malloc
  callf print_err, DBG_000

  callf malloc, 1032
  push rax
  callf print_int, rax


  callf malloc, 512
  callf print_int, rax
  pop rax
  callf free, rax
  callf malloc, 512 
  callf print_int, rax
  callf malloc, 512
  callf print_int, rax

  call exit

section .data
section .bss
