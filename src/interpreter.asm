%include "lexs.asm"

; Load token
; IDENT -> Load from table
;          Run if exists
;          Error out otherwise
; 
; INT
;   | FLOAT
;   | CHAR -> Push to the stack
; 
; STRING -> Load into allocation, store pointer
; 
; any keyowrd -> ERROR
; 
; OBRACE -> Go into def mode
; 
; Rest -> Error out or do bultin op
; 
; Def mode:
;   Check for ident in dictionary
;   Error out of exists
;   Otherwise read until CBRACE and store in allocation


section .text



section .bss
CODE_STACK  resb 2048
VALUE_STACK resb 4096
