
section .text

SRC_BUFFER_SIZE   equ 1024 * 10          ; 10KB
TOKEN_BUFFER_SIZE equ 1024 * 10

EOF equ -1

STATE_READY            equ 0
STATE_IDENT            equ 1
STATE_NUMBER           equ 2
STATE_STRING           equ 3
STATE_CHAR             equ 4
STATE_AMP              equ 5
STATE_VBAR             equ 6
STATE_LESS             equ 7
STATE_GREAT            equ 8
STATE_EQUAL            equ 9
STATE_BANG             equ 10
STATE_CHAR_END         equ 11
STATE_CHAR_ESC         equ 12
STATE_CHAR_ESC_HEX_1   equ 13
STATE_CHAR_ESC_HEX_2   equ 14
STATE_FLOAT            equ 15
STATE_FLOAT_DEC        equ 16
STATE_STRING_ESC       equ 17
STATE_STRING_ESC_HEX_1 equ 18
STATE_STRING_ESC_HEX_2 equ 19

                                         ; End of stream token
TK_EOS    equ 0
                                         ; String tokens
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
  alloc( SRC_BUFFER_SIZE )         ; Size
                                       ; + 1 so we can check for oversize
  call stdin_read, rsp, SRC_BUFFER_SIZE+1

  cmp rax, SRC_BUFFER_SIZE             ; Check for file size
  jg .err_source_code_too_big

.end_loop:
                                       ; ### Registers used:
                                       ; rax: function results and logic
                                       ; rbx: current character ( bl )
                                       ; rcx: buffer view length
                                       ; rdx: source buffer origin
                                       ; r8 : source buffer length
                                       ; r9 : pos count
                                       ; r10: line count
                                       ; r11: source buffer cursor
                                       ; r12: buffer view origin
                                       ; r13: token buffer length
                                       ; r14: token buffer cursor
                                       ; r15: current state

  mov r8 , rax                         ; Save the source buffer size
  lea r11, [rsp - 1]                   ; Source cursor, - 1 due to next_char
  mov rdx, rsp                         ; Store the soure code origin
  mov r12, r11                         ; Set our buffer view on the start
  xor rcx, rcx                         ; And the length of it to 0
  mov r9 , 1                           ; Start at pos 1
  mov r10, 1                           ; line 1

  test r8, r8
  jz .end                              ; Stop early if the buffer is empty
  
    blockstart                         ; Start a new scope
    alloc( TOKEN_BUFFER_SIZE + 8 )     ; Allocate the token buffer
    
    xor r13, r13                       ; Set the token buffer's length to 0
    mov r14, rsp                       ; Set the token buffers cursor to origin
    mov qword [rbp], 0                 ; Set the buffer's current length to 0
  
    mov r15, STATE_READY               ; Set-up the state
  
  .step_state:
    push rsi
    push rdi
    call print_err, DBG_000
    pop rdi
    pop rsi

    call next_char
  
  .hold_char:
    jmp [LEXER_JUMP_TABLE + r15 * 8]   ; Jump to the given state branch
  
  .state_ready:
    call is_ident_char
    test rax, rax
    jz .try_digit
    
    mov r15, STATE_IDENT
    jmp .step_state
    
  .try_digit:
    call is_digit_char
    test rax, rax
    jz .try_minus

    mov r15, STATE_NUMBER
    jmp .step_state

  .try_minus:
    cmp bl, '-'
    jne .try_dqoute
  
    mov r15, STATE_NUMBER
    jmp .step_state
  
  .try_dqoute:
    cmp bl, '"'
    jne .try_sqoute
    
    dec rcx
    inc r12                            ; Discard the first qoute

    mov r15, STATE_STRING
    jmp .step_state
  
  .try_sqoute:
    cmp bl, "'"
    jne .try_single_symbol
  
    mov r15, STATE_CHAR
    jmp .step_state
  
  .try_single_symbol:
    call is_single_symbol
    test rax, rax
    jz .try_amp
    
    mov rax, rbx
    call push_token
    mov r15, STATE_READY
    jmp .step_state
  
  .try_amp:
    cmp bl, '&'
    jne .try_vbar
  
    mov r15, STATE_AMP
    jmp .step_state
  
  .try_vbar:
    cmp bl, '|'
    jne .try_less
  
    mov r15, STATE_VBAR
    jmp .step_state
  
  .try_less:
    cmp bl, '<'
    jne .try_great
  
    mov r15, STATE_LESS
    jmp .step_state
  
  .try_great:
    cmp bl, '>'
    jne .try_equal
  
    mov r15, STATE_GREAT
    jmp .step_state
  
  .try_equal:
    cmp bl, '='
    jne .try_bang
  
    mov r15, STATE_EQUAL
    jmp .step_state
  
  .try_bang:
    cmp bl, '!'
    jne .try_whitespace
  
    mov r15, STATE_BANG
    jmp .step_state
  
  .try_whitespace:
    call is_whitespace_char
    test rax, rax
    jz .try_eof
  
    mov r15, STATE_READY
    dec r13                              ; Decreate view size, and move it along
    inc r14                              ; Discarding the char
    jmp .step_state
  
  .try_eof:
    cmp rbx, -1
    jne .invalid_token
    jmp .finish_lexing

  .state_ident:
    call is_ident_char
    test rax, rax
    jnz .step_state

    call is_digit_char
    test rax, rax
    jnz .step_state

    mov rax, TK_IDENT
    call push_token

    mov r15, STATE_READY
    jmp .hold_char

  .state_number:
    call is_digit_char
    test rax, rax
    jnz .step_state

    cmp bl, '.'
    jne .number_elipson

    mov r15, STATE_FLOAT
    jmp .step_state

  .number_elipson:
    mov rax, TK_INT
    call push_token

    mov r15, STATE_READY
    jmp .hold_char

  .state_float:
    call is_digit_char
    test rax, rax
    jz .invalid_float

    mov r15, STATE_FLOAT_DEC
    jmp .step_state

  .state_float_dec:
    call is_digit_char
    test rax, rax
    jnz .step_state

    mov rax, TK_FLOAT
    call push_token

    mov r15, STATE_READY
    jmp .hold_char

  .state_string:
    call is_string_char
    test rax, rax
    jnz .step_state

    cmp bl, '\'
    jne .string_end

    mov r15, STATE_STRING_ESC
    jmp .step_state

  .string_end:
    cmp bl, '"'
    jne .invalid_string

    dec rcx                            ; Don't include the last qoute
    mov rax, TK_STRING
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .state_string_esc:
    cmp bl, '\'
    jne .try_string_hex_esc

    mov r15, STATE_STRING
    jmp .step_state

  .try_string_hex_esc:
    cmp bl, 'x'
    jne .try_string_qout_esc

    mov r15, STATE_STRING_ESC_HEX_1
    jmp .step_state

  .try_string_qout_esc:
    cmp bl, '"'
    jne .invalid_string_escape

    mov r15, STATE_STRING
    jmp .step_state

  .state_string_esc_hex_1:
    call is_hex_char
    test rax, rax
    jne .invalid_hex_escape

    mov r15, STATE_STRING_ESC_HEX_2
    jmp .step_state

  .state_string_esc_hex_2:
    call is_hex_char
    test rax, rax
    jne .invalid_hex_escape

    mov r15, STATE_STRING
    jmp .step_state

  .state_char:
    call is_char_char
    test rax, rax
    jz .try_char_esc

    mov r15, STATE_CHAR_END

  .try_char_esc:
    cmp bl, '\'
    jne .invalid_char

    mov r15, STATE_CHAR_ESC
    jmp .step_state

  .state_char_end:
    cmp bl, "'"
    jne .invalid_char

    dec rcx                            ; Don't include the last qoute
    mov rax, TK_CHAR
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .state_char_esc:
    cmp bl, '\'
    jne .try_char_hex_esc

    mov r15, STATE_CHAR_END
    jmp .step_state

  .try_char_hex_esc:
    cmp bl, 'x'
    jne .try_char_qout_esc

    mov r15, STATE_CHAR_ESC_HEX_1
    jmp .step_state

  .try_char_qout_esc:
    cmp bl, "'"
    jne .invalid_char_escape

    mov r15, STATE_CHAR_END
    jmp .step_state

  .state_char_esc_hex_1:
    call is_hex_char
    test rax, rax
    jne .invalid_hex_escape

    mov r15, STATE_CHAR_ESC_HEX_2
    jmp .step_state

  .state_char_esc_hex_2:
    call is_hex_char
    test rax, rax
    jne .invalid_hex_escape

    mov r15, STATE_CHAR_END
    jmp .step_state

  .state_amp:
    cmp bl, '&'
    jne .dchar_elipson

    mov rax, TK_DAMP
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .state_vbar:
    cmp bl, '|'
    jne .dchar_elipson

    mov rax, TK_DVBAR
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .state_less:
    cmp bl, '='
    jne .dchar_elipson

    mov rax, TK_LESSEQ
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .state_great:
    cmp bl, '='
    jne .dchar_elipson

    mov rax, TK_GRETEQ
    call push_token

    mov r15, STATE_READY
    jmp .step_state
  
  .state_equal:
    cmp bl, '='
    jne .dchar_elipson

    mov rax, TK_DEQUAL
    call push_token

    mov r15, STATE_READY
    jmp .step_state
  
  .state_bang:
    cmp bl, '='
    jne .dchar_elipson

    mov rax, TK_NEQUAL
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .dchar_elipson:
    mov rax, rbx
    call push_token

    mov r15, STATE_READY
    jmp .step_state

  .invalid_token:
    call print_err, ERR_MSG_001

  .invalid_float:
    call print_err, ERR_MSG_002

  .invalid_string:
    call print_err, ERR_MSG_003

  .invalid_string_escape:
    call print_err, ERR_MSG_004

  .invalid_hex_escape:
    call print_err, ERR_MSG_005

  .invalid_char:
    call print_err, ERR_MSG_006

  .invalid_char_escape:
    call print_err, ERR_MSG_007

  .finish_lexing:
    ; TODO: Copy the token data into the source area
    blockend

.end:
  push rsi
  push rdi
  call print_err, DBG_003
  pop rdi
  pop rsi
    
  blockend
  ret

.err_source_code_too_big:
  call print_err, ERR_MSG_000
  blockend
  ret

next_char:
  inc r11                              ; Move source cursor ahead

  mov rax, r11
  sub rax, rdx
  cmp rax, r8
  jge .read_char                       ; Make sure there's a char to read

  mov rbx, EOF                         ; If there isn't, make the char EOF
  ret

.read_char:
  mov bl, [r11]                        ; Read a character from the source
  inc rcx                              ; Expend the buffer view to current char

  cmp bl, `\n`
  jne .bump_pos

  inc r10                              ; Next line
  mov r9, 1                            ; Reset pos count

.bump_pos:
  inc r9
  ret

push_token:
                                       ; Push the token id
  mov [r14], al
  inc r14                              ; Update the cursor and length
  inc r13

  cmp al, TK_CHAR
  jg .end
                                       ; Push the string, clear the buffer view
  mov [r14], rcx                       ; Push the string length
  add r13, 8
  
  mov rax, rcx                         ; Store the old buffer view length
  
  mov rsi, r12
  mov rdi, r14
  rep movsb                            ; Copy buffer view to token buffer

  add r13, rax                         ; Update buffer length
  mov r12, r11                         ; Move the buffer view along

.end:
  ret  

is_ident_char:
  mov rax, 1

  cmp bl, 'A'
  jl .not_upper
  cmp bl, 'Z'
  jg .not_upper
  ret

.not_upper:
  cmp bl, 'a'
  jl .not_lower
  cmp bl, 'z'
  jg .not_lower
  ret

.not_lower:
  cmp bl, '_'
  jne .not_ident_char
  ret

.not_ident_char:
  xor rax, rax
  ret

is_digit_char:
  xor rax, rax
  
  cmp bl, '0'
  jl .end
  cmp bl, '9'
  jg .end
  mov rax, 1
.end:
  ret

is_single_symbol:
  mov rax, 1

  cmp bl, '%'
  je .end

  cmp bl, '('
  jl .others
  cmp bl, '/'
  jle .end

.others:
  cmp bl, ';'
  je .end

  cmp bl, '^'
  je .end

  cmp bl, '{'
  je .end

  cmp bl, '}'
  je .end

  cmp bl, '~'
  je .end  

  xor rax, rax
.end:
  ret

is_whitespace_char:
  mov rax, 1

  cmp bl, ' '
  je .end

  cmp bl, `\t`
  je .end

  cmp bl, `\n`
  je .end

  cmp bl, `\r`
  je .end

  xor rax, rax
.end:
  ret

is_char_char:
  xor rax, rax

  cmp bl, "'"
  je .end
  cmp bl, `\n`
  je .end
  cmp rbx, EOF
  je .end
  mov rax, 1

.end:
  ret

is_string_char:
  xor rax, rax

  cmp bl, '"'
  je .end
  cmp bl, `\n`
  je .end
  cmp rbx, EOF
  je .end
  mov rax, 1

.end:
  ret

is_hex_char:
  mov rax, 1

  cmp bl, 'a'
  jl .try_upper
  cmp bl, 'f'
  jg .try_upper
  jmp .end

.try_upper:
  cmp bl, 'A'
  jl .try_digit
  cmp bl, 'F'
  jg .try_digit
  jmp .end

.try_digit:
  cmp bl, '0'
  jge .end
  cmp bl, '9'
  jle .end

  xor rax, rax  
.end:
  ret



section .data
str_const ERR_MSG_000, `Source code exceeds 10KB.\n`
str_const ERR_MSG_001, `Encountered invalid token.\n`
str_const ERR_MSG_002, `Invalid float literal, expected digits after '.'.\n`
str_const ERR_MSG_003, `Expected a terminating '"' before EOF/EOL.\n`
str_const ERR_MSG_004, `Invalid string escape code.\n`
str_const ERR_MSG_005, `Invalid hex escape code, expected two hex digits.\n`
str_const ERR_MSG_006, `Invalid char, expected single character followed by a terminating "'".\n`
str_const ERR_MSG_007, `Invalid char escape code.\n`

str_const DBG_000, `Wow\n`
str_const DBG_001, `Kek\n`
str_const DBG_002, `Rekt\n`
str_const DBG_003, `DanK\n`

str_const KW_FN    , "fn"
str_const KW_TYPE  , "type"
str_const KW_IF    , "if"
str_const KW_ELIF  , "elif"
str_const KW_ELSE  , "else"
str_const KW_LET   , "let"
str_const KW_RETURN, "return"

LEXER_JUMP_TABLE:
dq lex.state_ready           , lex.state_ident           , lex.state_number
dq lex.state_string          , lex.state_char            , lex.state_amp
dq lex.state_vbar            , lex.state_less            , lex.state_great
dq lex.state_equal           , lex.state_bang            , lex.state_char_end
dq lex.state_char_esc        , lex.state_char_esc_hex_1  , lex.state_char_esc_hex_2
dq lex.state_float           , lex.state_float_dec       , lex.state_string_esc
dq lex.state_string_esc_hex_1, lex.state_string_esc_hex_2

section .bss


