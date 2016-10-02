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
main:
_start:
  call init_malloc
  call lex
  mov rdi, rax
  mov rsi, rdx
  call parse
.inspect:
  mov r12, rax
  callf print_hex, [r12 + AST.error]
  cmp qword [r12 + AST.error], 0
  je .skip_print_err
  mov rdi, [r12 + AST.error_msg]
  call print_err
.skip_print_err:
  call exit

section .bss
