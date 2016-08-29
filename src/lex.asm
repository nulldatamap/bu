%include "state_table.asm"
%include "effect_table.asm"

section .text

SRC_BUFFER_SIZE   equ 1024 * 10          ; 10KB
TOKEN_BUFFER_SIZE equ 1024 * 10

TK_EOF    equ 0

TK_IDENT  equ 1
TK_INT    equ 2
TK_FLOAT  equ 3
TK_STRING equ 4
TK_CHAR   equ 5
                                         ; Keywords
TK_FN     equ 6
TK_TYPE   equ 7
TK_LET    equ 8
TK_IF     equ 9
TK_ELIF   equ 10
TK_ELSE   equ 11
TK_RETURN equ 12
                                         ; Multi-char symbols
TK_DEQUAL equ 13
TK_NEQUAL equ 14
TK_LESSEQ equ 15
TK_GRETEQ equ 16
TK_DAMP   equ 17
TK_DVBAR  equ 18
                                         ; Single-char symbols
TK_OPAREN equ '('
TK_CPAREN equ ')'
TK_COMMA  equ ','
TK_ASTER  equ '*'
TK_OBRACE equ '{'
TK_CBRACE equ '}'
TK_EQUAL  equ '='
TK_SEMI   equ ';'
TK_MINUS  equ '-'
TK_AMP    equ '&'
TK_BANG   equ '!'
TK_TILDE  equ '~'
TK_PLUS   equ '+'
TK_SLASH  equ '/'
TK_PRCNT  equ '%'
TK_VBAR   equ '|'
TK_HAT    equ '^'
TK_LESS   equ '<'
TK_GERAT  equ '>'
TK_DOT    equ '.'

; lex () int
lex:
  blockstart
  sub rsp, SRC_BUFFER_SIZE + TOKEN_BUFFER_SIZE
                                       ; + 1 so we can check for over
  lea rax, [rsp + TOKEN_BUFFER_SIZE]
  callf stdin_read, rax, SRC_BUFFER_SIZE+1

  cmp rax, SRC_BUFFER_SIZE             ; Check for file size
  jg .err_source_code_too_big

.end_loop:
                                       ; rax = TMP / EFFECT
                                       ; rbx = STATE 
                                       ; rcx = ------
                                       ; rdx = ------
                                       ; rsi = ------
                                       ; rdi = ------
                                       ; rbp = ------
                                       ; rsp = ------
                                       ; r8  = INPUT
                                       ; r9  = NEW_STATE 
                                       ; r10 = SOURCE_INDEX
                                       ; r11 = SOURCE_END
                                       ; r12 = LINE
                                       ; r13 = POS
                                       ; r14 = VALUE_BUFFER_INDEX
                                       ; r15 = TOKEN_BUFFER_INDEX
  lea r10, [rsp + TOKEN_BUFFER_SIZE]
  lea r11, [r10 + rax]

  mov r12, 1
  mov r13, 1
  mov r14, VALUE_BUFFER
  lea r15, [rsp]

  mov rbx, INITIAL_STATE               ; 0 is the READY state

.step:
  call next_char
                                       ; Lookup the next state
  mov rax, r8
  mov rdx, STATE_TABLE_WIDTH
  mul rdx
  add rax, STATE_TABLE
  xor r9, r9
  mov r9b, [rax + rbx]
                                       ; Lookup the effect for this step
  cmp r9, FINISHED_STATE               ; Check if we've reached the end state
  je .done_lexing

  mov rax, rbx
  mov rdx, EFFECT_TABLE_WIDTH
  mul rdx
  add rax, EFFECT_TABLE
  mov rax, [rax + r9 * 8]
  
; push r8
; push rbx
; push rax
; callf print_err, DBG_000
; callf print_int, [rsp + 16]
; callf print_int, [rsp + 8]
; callf print_int, r9
; callf print_err, DBG_001
; pop rax
; pop rbx
; pop r8

  cmp rax, 0  
  je .no_effect                        ; Check if it's a nop
  
  call rax                             ; Call the effect

.no_effect:
  cmp r9 , TERMINATING_STATES          ; Check if the lexer is done
  jge .done_lexing                     ; If finished lexing

  mov rbx, r9                          ; Update the state
  jmp .step                            ; And step again

.err_source_code_too_big:
  callf print_err, ERR_MSG_000
  blockend
  ret

.done_lexing:
  cmp r14, VALUE_BUFFER                ; If there's an unpushed value
  je .dont_flush

  call push_buffer                     ; Flush it

.dont_flush:
  mov byte [r15], TK_EOF               ; Write the EOF token
  inc r15

  push r8
  push rbx
  push rax

  lea rax, [rsp + 3 * 8 ]
  mov rbx, r15
  sub rbx, rax
  callf stdout_write, rax, rbx

  pop rax
  pop rbx
  pop r8
  
  mov rdi, r15
  sub rdi, rsp
  call malloc
  mov rbx, rax

  mov rdi, rax
  mov rsi, rsp
  mov rcx, r15
  sub rcx, rsp
  mov rdx, rcx
  rep movsb
  mov rax, rbx
  
  blockend
  ret

next_char:
  mov r8, EOS

  cmp r10, r11
  je .end                              ; Return early with EOS

  xor r8 , r8
  mov r8b, [r10]                       ; Load the character
  inc r10

  cmp r8, '\n'
  jne .skip_newline                    ; Handle newlines

  xor r13, r13                         ; Reset the position
  inc r12                              ; Increment the line count

.skip_newline:
  inc r13                              ; Increment the position

.end:
  ret

%macro push_kind 1
  cmp r14, VALUE_BUFFER                ; If there's an unpushed 
  je .skip_value_push

  call push_buffer

.skip_value_push:
  mov byte [r15], %1
  inc r15
%endmacro

%macro dbg 1
  push r8
  push rbx
  push rax

  callf print_err, DBG_F_%+ %1

  pop rax
  pop rbx
  pop r8
%endmacro

push_string:
  dbg 1
  push_kind TK_STRING
  ret

push_symbol:
  dbg 2
  push_kind r8b                        ; Push INPUT
  ret

push_char:
  dbg 3
  push_kind TK_CHAR
  ret

push_collect_int:
  dbg 4
  push_kind TK_INT
  call collect
  ret

push_collect_ident:
  dbg 5
  push_kind TK_IDENT
  call collect
  ret

err_invalid_char:
  dbg 6
  callf print_err, ERR_MSG_001
  ret

collect:
  dbg 7
  mov [r14], r8b
  inc r14
  ret

err_expected_str_term:
  dbg 8
  callf print_err, ERR_MSG_003
  ret

%macro cmp_kw_else 2
  mov rdx, [KW_ %+ %1]                 ; Read the length field
  lea rcx, [KW_ %+ %1 + 8]             ; The string's location
  call raw_str_cmp                     ; Compare the two strings
  test rax, rax
  jz %2
  
  mov byte [r15 - 1], TK_ %+ %1
  mov r14, VALUE_BUFFER
  ret
%endmacro

push_buffer:
; dbg 9
  mov al, [r15 - 1]                    ; Read the last written tag
  cmp al, TK_IDENT                     ; If it's an ident token
  jne .dont_keyword_check              ; Check if it maches a keyword

  mov rdi, r14
  sub rdi, VALUE_BUFFER                ; Get the buffer's length
  mov rsi, VALUE_BUFFER                ; And it's location

  cmp_kw_else FN, .try_type_kw

.try_type_kw:
  cmp_kw_else TYPE, .try_if_kw

.try_if_kw:
  cmp_kw_else IF, .try_elif_kw

.try_elif_kw:
  cmp_kw_else ELIF, .try_else_kw

.try_else_kw:
  cmp_kw_else ELSE, .try_let_kw

.try_let_kw:
  cmp_kw_else LET, .try_return_kw

.try_return_kw:
  cmp_kw_else RETURN, .dont_keyword_check

.dont_keyword_check:
  mov rcx, r14
  sub rcx, VALUE_BUFFER

  mov [r15], rcx
  add r15, 8

  mov rsi, VALUE_BUFFER
  mov rdi, r15

  rep movsb                            ; Copy the buffer over

  mov r15, rdi                         ; Update the token buffer cursor
  mov r14, VALUE_BUFFER                ; Reset the value buffer

  ret

push_raw_buffer:
  dbg 9
  mov rcx, r14
  sub rcx, VALUE_BUFFER

  mov rsi, VALUE_BUFFER
  mov rdi, r15

  rep movsb                            ; Copy the buffer over

  mov r15, rdi                         ; Update the token buffer cursor
  mov r14, VALUE_BUFFER                ; Reset the value buffer

  ret

err_expected_chr_term:
  dbg A
  callf print_err, ERR_MSG_006
  ret

err_invalid_null_chr:
  dbg B
  callf print_err, ERR_MSG_006
  ret

err_invalid_str_esc:
  dbg C
  callf print_err, ERR_MSG_004
  ret

collect_dqoute:
  dbg D
  mov byte [r14], '"'
  inc r14
  ret

err_invalid_hex_esc:
  dbg E
  callf print_err, ERR_MSG_005
  ret

collect_upper_hex:
  dbg F
  mov rax, r8
  shr rax, 4
  cmp rax, 3
  je .not_abdef                        ; Check if it's a number's bitfield

  add r8, 9                            ; If not, add 9 so that the ascii value
                                       ; macthes the numeric value in 4 low bits
.not_abdef:
  and r8, 0xF                          ; Isolate the 4 lower bits
  shl r8, 4                            ; Shift them to the upper 4 bits
  mov [r14], r8b
  ret

collect_lower_hex:
  dbg 10
  mov rax, r8
  shr rax, 4
  cmp rax, 3
  je .not_abdef

  add r8, 9

.not_abdef:
  and r8, 0xF
  or [r14], r8
  inc r14
  ret

err_invalid_chr_esc:
  dbg 11
  callf print_err, ERR_MSG_007
  ret

collect_sqoute:
  dbg 12
  mov byte [r14], "'"
  inc r14
  ret

err_invalid_number:
  dbg 13
  callf print_err, ERR_MSG_008
  ret

into_float_collect:
  dbg 14
  call collect
  mov byte [r15 - 1], TK_FLOAT              ; Rewrite the token kind
  ret

err_invalid_float:
  dbg 15
  callf print_err, ERR_MSG_002
  ret

into_lesseq:
  dbg 16
  mov byte [r15 - 1], TK_LESSEQ
  ret

into_dequal:
  dbg 17
  mov byte [r15 - 1], TK_DEQUAL
  ret

into_greateq:
  dbg 18
  mov byte [r15 - 1], TK_GRETEQ
  ret

into_damp:
  dbg 19
  mov byte [r15 - 1], TK_DAMP
  ret

into_dvbar:
  dbg 1A
  mov byte [r15 - 1], TK_DVBAR
  ret

into_nequal:
  dbg 1B
  mov byte [r15 - 1], TK_NEQUAL
  ret

err_invalid_effect:
  callf print_err, ERR_MSG_009
  ret

err_dbg:
  callf print_err, DBG_003
  ret


section .data
str_const ERR_MSG_000, `Source code exceeds 10KB.\n`
str_const ERR_MSG_001, `Encountered invalid token.\n`
str_const ERR_MSG_002, `Invalid float literal.\n`
str_const ERR_MSG_003, `Expected a terminating '"' before EOF/EOL.\n`
str_const ERR_MSG_004, `Invalid string escape code.\n`
str_const ERR_MSG_005, `Invalid hex escape code, expected two hex digits.\n`
str_const ERR_MSG_006, `Invalid char, expected single character followed by a terminating "'".\n`
str_const ERR_MSG_007, `Invalid char escape code.\n`
str_const ERR_MSG_008, `Invalid number literal.\n`
str_const ERR_MSG_009, `Invalid effect!\n`

str_const  DBG_F_1, `push_string\n`
str_const  DBG_F_2, `push_symbol\n`
str_const  DBG_F_3, `push_char\n`
str_const  DBG_F_4, `push_collect_int\n`
str_const  DBG_F_5, `push_collect_ident\n`
str_const  DBG_F_6, `err_invalid_char\n`
str_const  DBG_F_7, `collect\n`
str_const  DBG_F_8, `err_expected_str_term\n`
str_const  DBG_F_9, `push_buffer\n`
str_const  DBG_F_A, `err_expected_chr_term\n`
str_const  DBG_F_B, `err_invalid_null_chr\n`
str_const  DBG_F_C, `err_invalid_str_esc\n`
str_const  DBG_F_D, `collect_dqoute\n`
str_const  DBG_F_E, `err_invalid_hex_esc\n`
str_const  DBG_F_F, `collect_upper_hex\n`
str_const DBG_F_10, `collect_lower_hex\n`
str_const DBG_F_11, `err_invalid_chr_esc\n`
str_const DBG_F_12, `collect_sqoute\n`
str_const DBG_F_13, `err_invalid_number\n`
str_const DBG_F_14, `into_float_collect\n`
str_const DBG_F_15, `err_invalid_float\n`
str_const DBG_F_16, `into_lesseq\n`
str_const DBG_F_17, `into_dequal\n`
str_const DBG_F_18, `into_greateq\n`
str_const DBG_F_19, `into_damp\n`
str_const DBG_F_1A, `into_dvbar\n`
str_const DBG_F_1B, `into_nequal\n`
str_const DBG_F_FF, `err_invalid_effect\n`

str_const DBG_000, `========================\n`
str_const DBG_001, `-> `
str_const DBG_002, `.\n`
str_const DBG_003, `DanK\n`
str_const DBG_004, `------------------------\n`

str_const KW_FN    , "fn"
str_const KW_TYPE  , "type"
str_const KW_IF    , "if"
str_const KW_ELIF  , "elif"
str_const KW_ELSE  , "else"
str_const KW_LET   , "let"
str_const KW_RETURN, "return"

section .bss
VALUE_BUFFER resb 1024
