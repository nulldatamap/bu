section .text

struc AST
  .error     resb 1
  .error_msg resq 1
  .error_tok resq 1
  .typedefs  resb Vec_size
  .letdefs   resb Vec_size
  .fndefs    resb Vec_size
endstruc

TYDEF_ALIAS  equ 0
TYDEF_STRUCT equ 1

struc Typedef
  .name resb Vec_size
  .kind resb 1
  .type resb TYPE_MAX_SIZE
endstruc

NAMED_TYPE equ 0
PTR_TYPE   equ 1

struc Type
  .pointer resq 1
  .name    resb Vec_size
endstruc

struc Struct
  .fields resb Vec_size
endstruc

TYPE_MAX_SIZE equ Type_size

INT_EXPR   equ 0
STR_EXPR   equ 1
CHR_EXPR   equ 2
NAME_EXPR  equ 3
FIELD_EXPR equ 4
CALL_EXPR  equ 5
BIN_EXPR   equ 6
UNARY_EXPR equ 7
CAST_EXPR  equ 8

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
  .kind  resb 1
  .value resb Vec_size
endstruc

struc CharExpr
  .kind  resb 1
  .value resb 1
endstruc

struc IntExpr
  .kind  resb 1
  .value resq 1
endstruc

struc CastExpr
  .kind    resb 1
  .subject resq 1
  .type    resb Type_size
endstruc

EXPR_MAX_SIZE equ CastExpr_size

LETDEF_UNDEF equ 0
LETDEF_DEF   equ 1
LETDEF_CONST equ 2

struc Letdef
  .name    resb Vec_size
  .type    resb Type_size
  .defined resb 1
  .value   resb EXPR_MAX_SIZE
endstruc

struc Fndef
  .name      resb Vec_size
  .arguments resb Vec_size
  .return_ty resb Type_size
  .body      resb Vec_size
endstruc

EXPR_STMT equ 0
DEF_STMT  equ 1
RET_STMT  equ 2
IF_STMT   equ 3
ASGN_STMT equ 4

struc ExprStmt
  .kind resb 1
  .expr resb EXPR_MAX_SIZE
endstruc

struc AsgnStmt
  .kind resb 1
  .lhs  resb EXPR_MAX_SIZE
  .rhs  resb EXPR_MAX_SIZE
endstruc

struc DefStmt
  .kind resb 1
  .def  resb Letdef_size
endstruc

struc RetStmt
  .kind resb 1
  .expr resb EXPR_MAX_SIZE
endstruc

IFK_THEN equ 0
IFK_ELSE equ 1
IFK_ELIF equ 2

struc If
  .cond    resb EXPR_MAX_SIZE
  .then    resb Vec_size
  .if_kind resb 1
  .else    resb Vec_size
endstruc

struc IfStmt
  .kind    resb 1
  .if      resb If_size
endstruc

STMT_MAX_SIZE equ IfStmt_size

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

%macro load_tok 0
  cmp r14, r13
  jge _fatal_error_overread

  xor rax, rax
  mov al, [r12 + r14]
%endmacro

%macro expect 2
  load_tok
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
  je %%char_next

  ; Symbol:
  inc r14
  jmp %%end
%%char_next:
  add r14, 2
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
  mov r15, [rbp - 0x8]
  mov [r15 + AST.error], rax
  mov [r15 + AST.error_msg], rdx
  mov [r15 + AST.error_tok], r14

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

; display_tok () void
display_tok:
  push r14
  push r12
  
  mov r12, rdi
  mov r14, rsi

  xor rax, rax
  mov al, [r12 + r14]
  
  cmp al, TK_EOF
  je .as_eof

  cmp al, TK_IDENT
  je .as_string

  cmp al, TK_STRING
  je .as_string

  cmp al, TK_FLOAT
  je .as_string

  cmp al, TK_INT
  je .as_string

  cmp al, TK_CHAR
  je .as_char

  cmp al, TK_FN
  jb .as_symbol
  cmp al, TK_CONST
  ja .as_symbol
  sub al, TK_FN
  mov rdi, [KEYWORD_NAME_TABLE + 8 * rax]
  call print_err
  jmp .done

.as_symbol:
  lea rdi, [r14 + r12]
  mov rsi, 1
  call stderr_write
  jmp .done

.as_eof:
  mov rdi, TKS_EOF
  call print_err
  jmp .done

.as_char:
  mov rdi, MSG_SQT
  call print_err
  lea rdi, [r14 + r12 + 1]
  mov rsi, 1
  call stderr_write
  mov rdi, MSG_SQT
  call print_err
  jmp .done 

.as_string:
  mov rdi, MSG_DQT
  call print_err
  lea rdi, [r12 + r14 + 1]
  call print_err
  mov rdi, MSG_DQT
  call print_err
.done:
  pop r12
  pop r14
  ret

; parse ( buffer ptr, length int ) *AST
parse:
  blockstart
  sub rsp, 0x8
  push r12
  push r13
  push r14

  mov r12, rdi
  mov r13, rsi
  mov r14, 0

  ; Allocate the AST structure
  callf malloc, AST_size
  mov [rbp - 0x8], rax
  ; And initialize it
  callf new_AST, rax

.m_toplevel:
  mov rdi, r12
  mov rsi, r14
  call display_tok
  call write_err_nl
  ; Rule: program := (typedef | def | fun)*
  expect TK_EOF, .m_typedef
  jmp .done

.m_typedef:
  expect TK_TYPE, .m_letdef
  next
  ; Ready space on the typedef vector
  mov r15, [rbp - 0x8]
  lea rdi, [r15 + AST.typedefs]
  mov rsi, Typedef_size
  call Vec_grow
  mov rdi, rax
  push r15
  call _typedef
  pop r15
  carry_error_ast
  jmp .m_toplevel

.m_letdef:
  expect TK_LET, .m_fndef
  next
  ; Reserve space for the let definition, since its parse function is both
  ; responsible to parsing top-level lets and function level ones
  ; call _letdef
  mov r15, [rbp - 0x8]
  lea rdi, [r15 + AST.letdefs]
  mov rsi, Letdef_size
  call Vec_grow
  mov rdi, rax
  push r15
  call _letdef
  push r15
  carry_error_ast
  jmp .m_toplevel

.m_fndef:
   expect TK_FN, .syntax_error
   next
   mov r15, [rbp - 0x8]
   lea rdi, [r15 + AST.fndefs]
   mov rsi, Fndef_size
   call Vec_grow
   mov rdi, rax
   push r15
   call _fndef
   push r15
   carry_error_ast

   jmp .m_toplevel

.syntax_error:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_TOP_LEVEL
  carry_error_ast

.done:

  ; Return the AST
  mov rax, [rbp - 0x8]
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

  mov r15, rdi
  expect TK_IDENT, .expected_type_name
  name_from_token r15 + Typedef.name
  next
  expect TK_EQUAL, .m_struct
  next

  mov byte [r15 + Typedef.kind], TYDEF_ALIAS
  lea rdi, [r15 + Typedef.type]
  call _type
  carry_error .done
  jmp .m_semi

.m_struct:
  expect '{', .expected_eq_or_obrace
  next

  mov byte [r15 + Typedef.kind], TYDEF_STRUCT
  
  lea rdi, [r15 + Typedef.type]
  mov rsi, Vec_size + Type_size
  call new_Vec

.try_field:
  expect TK_IDENT, .expected_field_name
  
  lea rdi, [r15 + Typedef.type]
  mov rsi, Vec_size + Type_size
  call Vec_grow
  
  push r15
  push rax
  mov r15, rax
  name_from_token r15
  next
  pop r15

  lea rdi, [r15 + Vec_size]
  call _type
  carry_error .done
  pop r15
  
  expect '}', .try_field
  next

.m_semi:
  expect ';', .skip_semi
  next

.skip_semi:
  mov rax, 0
  jmp .done

.expected_field_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_FIELD_NAME
.expected_eq_or_obrace:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_EQ_OR_OBRACE
  jmp .done
.expected_type_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_TYPE_NAME
.done:
  blockend
  ret

; _type ( ty *Type ) (int, str)
_type:
  mov qword [rdi + Type.pointer], 0
.m_aster:
  expect TK_ASTER, .ty_name
  next
  inc qword [rdi + Type.pointer]
  jmp .m_aster
.ty_name:
  expect TK_IDENT, .expected_type_name
  ; Copy the source code string into a string buffer for the type name
  push r15
  mov r15, rdi
  ; Allocate the string buffer
  name_from_token r15 + Type.name
  pop r15
  next
  mov rax, 0
  ret

.expected_type_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_TYPE
  ret

_fndef:
  mov r15, rdi
  lea rdi, [r15 + Fndef.arguments]
  mov rsi, Vec_size + Type_size
  call new_Vec

  expect TK_IDENT, .expected_fnname
  name_from_token r15 + Fndef.name

  next
  expect '(', .expected_oparen
  next
  expect ')', .try_argument
  next
  jmp .return_ty

.try_argument:
  expect TK_IDENT, .expected_arg

  lea rdi, [r15 + Fndef.arguments]
  mov rsi, Vec_size + Type_size
  call Vec_grow

  push r15
  push rax
  mov r15, rax
  name_from_token r15
  next
  pop r15

  lea rdi, [r15 + Vec_size]
  call _type
  carry_error .done

  pop r15
  expect ',', .expect_end
  next
  jmp .try_argument

.expect_end:
  expect ')', .expected_arg_or_end
  next

.return_ty:
  lea rdi, [r15 + Fndef.return_ty]
  call _type
  carry_error .done

  lea rdi, [r15 + Fndef.body]
  call _block
  jmp .success

.expected_arg_or_end:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_ARG_OR_END
  jmp .done
.expected_arg:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_ARGUMENT
  jmp .done
.expected_oparen:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_OPAREN
  jmp .done
.expected_fnname:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_FN_NAME
  jmp .done
.success:
  mov rax, 0
.done:
  ret

_block:
  mov r15, rdi
  mov rsi, STMT_MAX_SIZE
  call new_Vec
  expect '{', .expected_obrace
  next

  ; jmp .try_def

.try_another:
  expect '}', .try_def
  next
  jmp .success

.try_def:
  expect TK_LET, .m_ret
  next
  callf Vec_grow, r15, STMT_MAX_SIZE
  mov byte [rax + DefStmt.kind], DEF_STMT
  lea rdi, [rax + DefStmt.def]
  push r15
  call _letdef
  pop r15
  carry_error .done
  jmp .try_another

.m_ret:
  expect TK_RETURN, .m_if
  next
  callf Vec_grow, r15, STMT_MAX_SIZE
  mov byte [rax + RetStmt.kind], RET_STMT
  lea rdi, [rax + RetStmt.expr]
  push r15
  call _expr
  pop r15
  carry_error .done
  jmp .try_another

.m_if:
  expect TK_IF, .m_asgn
  next

  callf Vec_grow, r15, STMT_MAX_SIZE
  mov byte [rax + IfStmt.kind], IF_STMT
  lea rdi, [rax + 1]
  push r15
  call _if
  pop r15
  carry_error .done

  jmp .try_another

.m_asgn:
  callf Vec_grow, r15, STMT_MAX_SIZE
  lea rdi, [rax + ExprStmt.expr]
  mov r8, rax
  push r8
  push r15
  call _expr
  pop r15
  pop r8
  carry_error .done

  expect TK_EQUAL, .skip_asgn
  next

  mov byte [r8 + AsgnStmt.kind], ASGN_STMT
  lea rdi, [r8 + AsgnStmt.rhs]
  push r15
  call _expr
  pop r15
  carry_error .done

  jmp .try_another

.skip_asgn:
  mov byte [r8 + ExprStmt.kind], EXPR_STMT
  jmp .try_another

.expected_obrace:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_OBRACE
  ret
.expected_cbrace:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_CBRACE
  ret
.success:
  mov rax, 0
.done:
  ret

; _letdef ( ld *Letdef ) (int, *str)
_letdef:
  push rbx
  mov r15, rdi
  xor rbx, rbx
  expect TK_CONST, .not_const
  next
  mov byte [r15 + Letdef.defined], LETDEF_CONST
  mov rbx, 1

.not_const:
  expect TK_IDENT, .expected_variable_name
  name_from_token r15 + Letdef.name
  next
  lea rdi, [r15 + Letdef.type]
  call _type
  carry_error .done
  expect TK_EQUAL, .no_def
  next

  test rbx, rbx
  jnz .skip_set_def
  mov byte [r15 + Letdef.defined], LETDEF_DEF
.skip_set_def:
  lea rdi, [r15 + Letdef.value]
  push r15
  call _expr
  pop r15

  carry_error .done
  jmp .done

.expected_variable_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_VAR_NAME
  jmp .done
.no_def:
  test rbx, rbx
  jnz .err_expected_eq
  mov byte [r15 + Letdef.defined], LETDEF_UNDEF
  
  mov rax, 0
  jmp .done
.err_expected_eq:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_CONST_EQ
.done:
  pop rbx
  ret

_if:
  mov r15, rdi
  mov byte [r15 + If.if_kind], IFK_THEN
  lea rdi, [r15 + If.cond]
  push r15
  call _expr
  pop r15
  carry_error .done

  lea rdi, [r15 + If.then]
  push r15
  call _block
  pop r15
  carry_error .done

.m_elif:
  expect TK_ELIF, .m_else
  next
  mov byte [r15 + If.if_kind], IFK_ELIF

  callf malloc, If_size
  mov qword [r15 + If.else], rax
  push r15
  mov rdi, rax
  call _if
  pop r15
  carry_error .done
  jmp .success

.m_else:
  expect TK_ELSE, .success
  next

  mov byte [r15 + If.if_kind], IFK_ELSE
  lea rdi, [r15 + If.else]
  push r15
  call _block
  pop r15
  carry_error .done

.success:
  mov rax, 0
.done:
  ret

_expr:
_unterm:
  mov r15, rdi
  ; Test unop
  ; '-' | '*' | '&' | '!' | '~'
  load_tok
  cmp al, '-'
  je .make_un
  cmp al, '*'
  je .make_un
  cmp al, '&'
  je .make_un
  cmp al, '!'
  je .make_un
  cmp al, '~'
  jne .try_binterm

.make_un:
  mov byte [r15 + UnaryExpr.kind], UNARY_EXPR
  mov byte [r15 + UnaryExpr.operator], al
  mov rdi, EXPR_MAX_SIZE
  next
  call malloc
  mov qword [r15 + UnaryExpr.operand], rax
  mov rdi, rax

  call _expr
  carry_error .done
  jmp .skip_try_binterm

.try_binterm:
  call _binterm
  carry_error .done

.skip_try_binterm:
  load_tok
  cmp al, ';'
  jne .success
  next

.success:
  mov rax, 0

.done:
  ret

_binterm:
  push rdi
  call _aterm
  pop rdi
  mov r15, rdi
  carry_error .done

  ; Test binop
  ; '+' | '-' | '*' | '/' | '%' | '&&' | '||' | '&' | '|' | '^' | '==' | '!='
  ; '<' | '>' | '<=' | '>='
  load_tok
  cmp al, TK_DEQUAL
  jl .try_pro
  cmp al, TK_DVBAR
  jg .try_pro
  jmp .make_binterm

.try_pro:
  cmp al, '%'
  je .make_binterm
.try_amp:
  cmp al, '&'
  je .make_binterm
.try_ast:
  cmp al, '*'
  je .make_binterm
.try_plu:
  cmp al, '+'
  je .make_binterm
.try_sub:
  cmp al, '-'
  je .make_binterm
.try_sla:
  cmp al, '/'
  je .make_binterm
.try_le:
  cmp al, '<'
  je .make_binterm
.try_gr:
  cmp al, '>'
  je .make_binterm
.try_car:
  cmp al, '^'
  je .make_binterm
.try_vba:
  cmp al, '|'
  je .make_binterm
  ; The token wasn't a binop, so assume we're not making a binterm
  jmp .success

.make_binterm:
  push rax
  next
  ; Store the op
  callf malloc, EXPR_MAX_SIZE
  mov rdx, rax
  mov rdi, rax
  mov rsi, r15
  mov rcx, EXPR_MAX_SIZE
  rep movsb
  pop rax

  ; r15 is getting moved into the tokens
  mov byte [r15 + BinaryExpr.kind], BIN_EXPR
  mov [r15 + BinaryExpr.operator], al
  mov [r15 + BinaryExpr.left], rdx
  callf malloc, EXPR_MAX_SIZE
  mov [r15 + BinaryExpr.right], rax
  push r15
  mov rdi, rax
  call _expr
  pop r15
  carry_error .done

.success:
  mov rax, 0

.done:
  ret

_aterm:
  push rdi
  call _castterm
  pop r15
  carry_error .done

.m_chain:
  ; Attempt a possible chain of properties and/or function calls
  expect '.', .try_call
  next
  expect TK_IDENT, .expected_name
  callf malloc, EXPR_MAX_SIZE

  mov rdx, rax
  mov rdi, rax
  mov rsi, r15
  mov rcx, EXPR_MAX_SIZE
  rep movsb

  mov byte [r15 + FieldExpr.kind], FIELD_EXPR
  mov [r15 + FieldExpr.subject], rdx
  name_from_token r15 + FieldExpr.field
  next

  jmp .m_chain

.try_call:
  expect '(', .success
  next
  callf malloc, EXPR_MAX_SIZE

  mov rdx, rax
  mov rdi, rax
  mov rsi, r15
  mov rcx, EXPR_MAX_SIZE
  rep movsb

  mov byte [r15 + CallExpr.kind], CALL_EXPR
  mov qword [r15 + CallExpr.callee], rdx
  lea rdi, [r15 + CallExpr.args]
  mov rsi, EXPR_MAX_SIZE
  call new_Vec
  ; Read the arguments
.m_arg:
  expect ')', .try_arg
  next
  jmp .m_chain

.try_arg:
  lea rdi, [r15 + CallExpr.args]
  mov rsi, EXPR_MAX_SIZE
  call Vec_grow
  mov rdi, rax
  push r15
  ; Allocate space for the sub-expression for the argument on the vector
  ; If the call fails, set the size of the vector back to what it was before
  ; the allocation.
  call _expr
  pop r15
  carry_error .deallocate_expr

  expect ',', .try_closing
  next

  jmp .try_arg

.try_closing:
  expect ')', .expected_cparen
  next
  jmp .m_chain

.deallocate_expr:
  sub qword [r15 + CallExpr.args + Vec.length], EXPR_MAX_SIZE
  jmp .done

.success:
  mov rax, 0
  jmp .done

.expected_name:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_VAR_NAME
  jmp .done

.expected_cparen:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_CPAREN

.done:
  ret

_castterm:
  push r15
  call _term
  pop r15
  carry_error .done

  expect TK_AS, .success
  next

  mov rdi, EXPR_MAX_SIZE
  call malloc
  mov rdx, rax
  mov rdi, rax
  mov rsi, r15
  mov rcx, EXPR_MAX_SIZE
  rep movsb

  mov byte [r15 + CastExpr.kind], CAST_EXPR
  mov qword [r15 + CastExpr.subject], rdx
  lea rdi, [r15 + CastExpr.type]
  call _type
  carry_error .done

.success:
  mov rax, 0
.done:
  ret

_term:
  mov r15, rdi
  expect '(', .try_named
  next
  mov rdi, r15
  call _expr
  carry_error .done
  expect ')', .expected_cparen
  next
  jmp .success

.try_named:
  expect TK_IDENT, .try_lit
  mov byte [r15 + NameExpr.kind], NAME_EXPR
  name_from_token r15 + NameExpr.name
  next
  jmp .success

.try_lit:
  mov rdi, r15
  call _lit
  carry_error .done

.success:
  mov rax, 0
  jmp .done

.expected_cparen:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_CPAREN

.done:
  ret

_lit:
  mov r15, rdi
  expect TK_INT, .try_string
  mov byte [r15 + IntExpr.kind], INT_EXPR
  lea rdi, [r14 + r12 + 1]
  call str2int
  mov [r15 + IntExpr.value], rax
  jmp .success

.try_string:
  expect TK_STRING, .try_char
  mov byte [r15 + StringExpr.kind], STR_EXPR
  name_from_token r15 + StringExpr.value
  jmp .success

.try_char:
  expect TK_CHAR, .expected_literal
  mov byte [r15 + CharExpr.kind], CHR_EXPR
  mov al, [r14 + r12 + 1]
  mov [r15 + CharExpr.value], al

.success:
  next
  mov rax, 0
  jmp .done
.expected_literal:
  mov rax, SYNTAX_ERROR
  mov rdx, ERR_EXPECTED_LITERAL
.done:
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
str_const ERR_EXPECTED_LITERAL, "Expected a int, char or string."
str_const ERR_EXPECTED_OPAREN, "Expected function arguments."
str_const ERR_EXPECTED_CPAREN, "Expected ')'."
str_const ERR_EXPECTED_FN_NAME, "Expected function name."
str_const ERR_EXPECTED_ARGUMENT, "Expected function argument."
str_const ERR_EXPECTED_OBRACE, "Expected '{'."
str_const ERR_EXPECTED_CBRACE, "Expected '}'."
str_const ERR_EXPECTED_EQ_OR_OBRACE, "Expected '=' or '{'."
str_const ERR_EXPECTED_FIELD_NAME, "Expected field name or '}'."
str_const ERR_EXPECTED_ARG_OR_END, "Expected another argument or ')'."
str_const ERR_EXPECTED_CONST_EQ, "Expected '=', constants must have a value."

; Keyword table
str_const KWS_FN,     "fn"
str_const KWS_TYPE,   "type"
str_const KWS_LET,    "let"
str_const KWS_IF,     "if"
str_const KWS_ELIF,   "elif"
str_const KWS_ELSE,   "else"
str_const KWS_RETURN, "return"
str_const KWS_AS,     "as"
str_const KWS_CONST,  "const"

str_const TKS_EOF, "<eof>"
str_const MSG_SQT, "'"
str_const MSG_DQT, `"`

KEYWORD_NAME_TABLE:
  dq KWS_FN
  dq KWS_TYPE
  dq KWS_LET
  dq KWS_IF
  dq KWS_ELIF
  dq KWS_ELSE
  dq KWS_RETURN
  dq KWS_AS
  dq KWS_CONST
