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
  call init_malloc
  callf malloc, 1032
  push rax
  callf print_int, rax

  callf malloc, 512
  callf print_err, DBG_000
  callf print_int, rax
  pop rax
  callf free, rax
  callf malloc, 512 
  callf print_int, rax
  callf malloc, 512
  
  call mem_stat
  callf print_int, rax
  callf print_int, [used_bytes]
  callf print_int, [free_bytes]

  call exit

section .data
section .bss
