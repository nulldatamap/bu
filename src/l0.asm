; Buttom Up
; Level 0, assembly.
; Parses and compiles l1
%include "macros.asm"
%include "io.asm"
%include "mem.asm"
%include "vec.asm"
%include "lex.asm"
%include "parse.asm"
%include "validate.asm"

section .text

global _start
main:
_start:
  call init_malloc
  call lex
  push rax
  mov rdi, rax
  mov rsi, rdx
  call parse
.inspect:
%ifdef ANALYSE
  call _memdump
%else
  mov r12, rax
  xor rdi, rdi
  mov dil, [r12 + AST.error]
  call print_hex
  cmp byte [r12 + AST.error], 0
  je .skip_print_err
  mov rdi, [r12 + AST.error_msg]
  call print_err
  mov rdi, MSG_GOT
  call print_err
  mov rsi, [r12 + AST.error_tok]
  pop rdi
  call display_tok
  call write_err_nl
%endif
.skip_print_err:
  call exit

section .bss
section .data
str_const MSG_GOT, `\nGot: `
