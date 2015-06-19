
section .text

SRC_BUFFER_SIZE   equ 1024 * 10          ; 10KB
TOKEN_BUFFER_SIZe equ 1024 * 10

STATE_READY equ 0
STATE_IDENT equ 1

                                         ; End of stream token
TK_EOS    equ 0
                                         ; String tokens
TK_IDENT  equ 1
TK_NUMBER equ 2
TK_STRING equ 3
TK_CHAR   equ 4
                                         ; Keywords
TK_FN     equ 5
TK_TYPE   equ 6
TK_LET    equ 7
TK_IF     equ 8
TK_ELIF   equ 9
TK_ELSE   equ 10
TK_RETURN equ 11
                                         ; Multi-char symbols
TK_DEQUAL equ 12
TK_NEQUAL equ 13
TK_LESSEQ equ 14
TK_GRETEQ equ 15
TK_DAMP   equ 16
TK_DVBAR  equ 17
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
  alloc( SRC_BUFFER_SIZE + 8 )         ; Size + length field
      
  call read_str, rsp, SRC_BUFFER_SIZE+1; + 1 so we can check for oversize

  cmp rax, SRC_BUFFER_SIZE             ; Check for file size
  jg .err_source_code_too_big

.end_loop:
                                       ; ### Registers used:
                                       ; rax: function results and logic
                                       ; rbx: current character ( bl )
                                       ; rcx: buffer view length
                                       ; r11: source buffer cursor
                                       ; r12: buffer view origin
                                       ; r13: Token buffer length
                                       ; r14: Token buffer cursor
                                       ; r15: current state

  mov r11, rsp                         ; Ready the source buffer
  mov r12, r11                         ; Set our buffer view on the start
  xor rcx, rcx                         ; And the length of it to 0

  mov rax, [rbp]                       ; Read the length of the buffer
  test rax, rax
  jz .end                              ; Stop early if the buffer is empty
  
    blockstart                         ; Start a new scope
    alloc( TOKEN_BUFFER_SIZE + 8 )     ; Allocate the token buffer
    
    xor r13, r13                       ; Set the token buffer's length to 0
    mov r14, rsp                       ; Set the token buffers cursor to origin
    mov [rbp], 0                       ; Set the buffer's current length to 0
  
    mov r15, STATE_READY               ; Set-up the state
  
  .step_state:
    mov bl, [r11]                      ; Read a character from the source
    inc rcx                            ; Expend the buffer view to current char
    jmp [LEXER_JUMP_TABLE + r15 * 8]   ; Jump to the given state branch
  
  .state_ready:
    call is_ident_char
    test rax, rax
    jz .try_digit
    
    mov r15, STATE_IDENT
    jmp .step_state
    
  .try_digit
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

  mov r15, STATE_STRING
  jmp .state_state

.try_sqoute:
  cmp bl, "'"
  jne .try_sinle_symbol

  mov r15, STATE_CHAR
  jmp .step_state

.try_single_symbol:
  call is_single_symbol
  test rax, rax
  jz .try_amp

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
  jz .invalid_token

  mov r15, STATE_READY
  dec r13
  inc r14                                            

  ; ..............

  .state_ident:
  
    blockend

.end:
  xor rax, rax                         ; Succeeded
  blockend
  ret
                                       ; ============== FAILURES ==============
.err_source_code_too_big:
  call print_err, ERR_MSG_000
  blockend
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
  add r12, rax                         ; Move the buffer view along

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
.end
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


section .data
str_const ERR_MSG_000, `Source code exceeds 10KB.\n`

str_const KW_FN    , "fn"
str_const KW_TYPE  , "type"
str_const KW_IF    , "if"
str_const KW_ELIF  , "elif"
str_const KW_ELSE  , "else"
str_const KW_LET   , "let"
str_const KW_RETURN, "return"

LEXER_JUMP_TABLE:
dq lex.state_ready, lex.state_ident

section .bss


