
_add:
  %define _a [rbp + 8]
  %define _b [rbp + 16]
  mov rax, _a
  mov rbx, _b
  add rax, rbx
  ret 16
