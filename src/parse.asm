section .text

struc AST
  .error     resb 1
  .error_msg resq 1
  .error_tok resq 1
  .typedefs  resb Vec_size
  .letdefs   resb Vec_size
  .fndefs    resb Vec_size
endstruc

struc Typedef
  .name resb Vec_size
  .type resb Type_size
endstruc

NAMED_TYPE equ 0
PTR_TYPE   equ 1

struc Type
  .kind resb 1
  ; Union, if it's a pointer
  ; .type resq 1
  .name resb Vec_size
endstruc

struc Letdef
;  .name    resb Vec_size
;  .defined resb 1
;  .value   resb Value_size
endstruc

struc UnaryExpr
  .kind     resb 1
  .operator resb 1
  .operand  resq 1
endstruc

struc BinaryExpr
  .kind     resb 1
  .operator resb 1
  .left     resq 1
  .right    resq 1
endstruc

struc CallExpr
  .kind   resb 1
  .callee resq 1
  .args   resb Vec_size
endstruc

struc FieldExpr
  .kind    resb 1
  .subject resq 1
  .field   resb Vec_size
endstruc

struc NameExpr
  .kind resb 1
  .name resq Vec_size
endstruc

struc StringExpr
  .kind   resb 1
  .data   resb Vec_size
endstruc

struc CharExpr
  .kind resb 1
  .char resb 1
endstruc

struc IntExpr
  .kind  resb 1
  .value resq 1
endstruc

struc Fndef
endstruc

; new_AST ( ast *AST )
new_AST:
  blockstart
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
  mov rsi, Letdef_size * 8
  call new_Vec

  lea rdi, [r12 + AST.fndefs]
  mov rsi, Fndef_size * 8
  call new_Vec

  pop r12
  blockend
  ret

%macro expect 2
  cmp r14, r13
  jge _fatal_error_overread
  
  xor rax, rax
  mov al, [r12 + r14]
  cmp al, %1
  jne %2
%endmacro

%macro next 0
  cmp r14, r13
  jge _fatal_error_overread
  
  mov al, [r12 + r14]
  ; Find out what token this is and skip the needed amount of bytes
  cmp al, TK_IDENT
  je %%string_next

  cmp al, TK_STRING
  je %%string_next

  cmp al, TK_FLOAT
  je %%string_next

  cmp al, TK_INT
  je %%string_next

  cmp al, TK_CHAR
  je %%string_next
  ; Symbol:
  inc r14
  jmp %%end
%%string_next:
  ; Skip length field + string data (1 + 8 + n)
  mov rax, [r12 + r14 + 1]
  add r14, rax
  add r14, 8 + 1
%%end:
%endmacro

%macro carry_error 0
  cmp rax, 0
  je .skip_error_carry
  ret

.skip_error_carry:

%endmacro

%macro carry_error 1
  cmp rax, 0
  jne %1
%endmacro

%macro carry_error_ast 0
  cmp rax, 0
  je %%.skip_storing

  mov [r15 + AST.error], rax
  mov [r15 + AST.error_msg], rdx

  jmp .done
  
%%.skip_storing:

%endmacro 

%macro name_from_token 1
  ; Load the address of the ident string
  lea rax, [r14 + 1]
  add rax, r12
  ; Write the string to a new vector
  lea rdi, [%1]
  mov rsi, [rax]
  call new_Vec

  lea rdi, [%1]
  ; Push all the contents of the string
  lea rax, [1 + r12 + r14]
  mov rdx, [rax]
  lea rsi, [rax + 8]
  call Vec_push_all
%endmacro

; parse ( buffer ptr, length int ) *AST
parse:
  blockstart
  push r12
  push r13
  push r14
  push r15

  mov r12, rdi
  mov r13, rsi
  mov r14, 0
  
  ; Allocate the AST structure
  callf malloc, AST_size
  mov r15, rax
  ; And initialize it
  callf new_AST, rax

.m_toplevel:
  ; Rule: program := (typedef | def | fun)*
  expect TK_EOF, .m_typedef
  jmp .done
  
.m_typedef:
  expect TK_TYPE, .m_letdef
  next
  ; Ready space on the typedef vector
  lea rdi, [r15 + AST.typedefs]
  mov rsi, Typedef_size
  call Vec_grow
  mov rdi, rax
  call _typedef
  carry_error_ast
  jmp .done

.m_letdef:
  expect TK_LET, .m_fndef
  next
  ; Reserve space for the let definition, since its parse function is both
  ; responsible to parsing top-level lets and function level ones
  ; call _letdef
  lea rdi, [r15 + AST.letdefs]
  mov rsi, Letdef_size
  call Vec_grow
  mov rdi, rax
  call _letdef
  carry_error_ast
  jmp .done
  

.m_fndef:
   expect TK_FN, .syntax_error
   next

   jmp .m_toplevel

.syntax_error:
  mov byte [r15 + AST.error], SYNTAX_ERROR
  lea rax, [r12 + r14]
  mov [r15 + AST.error_tok], rax

.done:
  
  ; Return the AST
  mov rax, r15
  pop r15
  pop r14
  pop r13
  pop r12
  blockend
  ret

_fatal_error_overread:
  callf print_err, ERR_FATAL_OVERREAD
  call exit

; _typedef ( td *Typedef ) (int, *str)
_typedef:
  blockstart
  push r15
  
  mov r15, rdi
  expect TK_IDENT, .expected_type_name
  name_from_token r15 + Typedef.name

  next
  expect TK_EQUAL, .expected_eq
  next

  lea rdi, [r15 + Typedef.type]
  call _type
  carry_error .done

  mov rax, 0
  jmp .done

.expected_eq:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_EQ
  jmp .done
.expected_type_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_TYPE_NAME
.done:
  pop r15
  blockend
  ret

; _type ( ty *Type ) (int, str)
_type:
.m_aster:
  expect TK_ASTER, .ty_name
  next
  ; Create a pointer type and read it's "pointing to" type
  mov byte [rdi + Type.kind], PTR_TYPE
  
  push rdi
  mov rdi, Type_size
  call malloc
  pop rdi

  mov [rdi + Type.name], rax
  mov rdi, rax
  ; Read the "pointing to" type of the pointer type
  call _type
  carry_error
  ret

.ty_name:
  push r15
  expect TK_IDENT, .expected_type_name
  mov byte [rdi + Type.kind], NAMED_TYPE
  ; Copy the source code string into a string buffer for the type name
  
  ; Allocate the string buffer
  name_from_token r15 + Type.name
  next
  mov rax, 0
  pop r15
  ret

.expected_type_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_TYPE
  pop r15
  ret

; _letdef ( ld *Letdef ) (int, *str)
_letdef:
  expect TK_IDENT, .expected_variable_name
  mov rax, 0
  ret

.expected_variable_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_VAR_NAME
  ret


section .data
SYNTAX_ERROR equ 1

str_const ERR_FATAL_OVERREAD, "Fatal error: the token buffer has been overread."
; Syntax errors
str_const ERR_TOP_LEVEL, "Expected a function, type defintion or toplevel let binding."
str_const ERR_EXPECTED_TYPE_NAME, "Expected a type name."
str_const ERR_EXPECTED_EQ, "Expected '='."
str_const ERR_EXPECTED_TYPE, "Expected type name or '*'"
str_const ERR_EXPECTED_VAR_NAME, "Expected variable name."
