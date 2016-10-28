section .text

; type Typemap = Vec
; Typemap_insert( tm *Typemap, key *Expr, ty *Type ) void
Typemap_insert:
  ; Allocate space for an entry
  push rsi
  push rdi
  mov rsi, 8 + Type_size
  call Vec_grow
  pop rdi
  pop rsi
  ; Write the key
  mov qword [rax], rsi
  ; And setup a memcopy for the type
  mov rdx, rdi
  lea rdi, [rax + 8]
  mov rsi, rdx
  mov rcx, Type_size
  rep movsb
  
  ret

; Typemap_lookup( tm *Typemap, key *Expr ) *Type
Typemap_lookup:
  mov rdx, [rdi + Vec.length]
  mov rax, [rdi + Vec.data]
.reloop:
  cmp rsi, [rax]
  je .has_key
  lea rax, [rax + 8 + Type_size]
  cmp rax, rdx
  jb .reloop

  xor rax, rax
  ret
.has_key:
  lea rax, [rax + 8]
  ret

; assign_types( ast *AST ) (int, *void)
assign_types:
  ; First validate let definition

section .data
