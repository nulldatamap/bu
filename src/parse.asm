section .text

struc AST
  .error     resb 1
  .error_msg resq 1
  .typedefs  resb Vec_size
  .letdefs   resb Vec_size
  .fndefs    resb Vec_size
endstruc

struc Typedef
;  .name resb Vec_size
;  .type resb Type_size
endstruc

struc Letdef
;  .name    resb Vec_size
;  .defined resb 1
;  .value   resb Value_size
endstruc

struc Fndef
endstruc

; new_AST ( ast *AST )
new_AST:
  push r12
  mov r12, rdi
  ; Starts off in a non-error state
  mov byte  [r12 + AST.error], 0
  mov qword [r12 + AST.error_msg], 0
  ; Allocate the definition vectors
  lea rdi, [r12 + AST.typedefs]
  mov rsi, Typedef_size * 8
  call new_Vec

  lea rdi, [r12 + AST.letdefs]
  mov rsi, Letdef_size
  call new_Vec

  lea rdi, [r12 + AST.fndefs]
  mov rsi, Fndef_size
  call new_Vec

  pop r12
  ret

struc parse_stack
  .ast resq 1
endstruc

; parse ( buffer ptr, length int ) *AST
parse:
  blockstart
  sub rsp, parse_stack_size
  push r12
  push r13
  push r14

  mov r12, rdi
  mov r13, rsi
  mov r14, 0
  
  ; Allocate the AST structure
  callf malloc, AST_size
  mov [rbp + parse_stack.ast], rax
  ; And initialize it
  callf new_AST, rax

  ; Return the AST
  mov rax, [rbp + parse_stack.ast]
  pop r14
  pop r13
  pop r12
  blockend
  ret

