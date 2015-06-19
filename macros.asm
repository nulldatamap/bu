
%macro blockstart 0
  push rbp
  mov rbp, rsp
%endmacro

%macro blockend 0
  mov rsp, rbp
  pop rbp
%endmacro

%define alloc( c ) sub rsp, c

%macro call 2
  mov rdi, %2
  call %1
%endmacro

%macro call 3
  mov rdi, %2
  mov rsi, %3
  call %1
%endmacro

%macro str_const 2
  %strlen %[%1 %+ _LEN_] %2
  %1:
  dq %[%1 %+ _LEN_]
  db %2
%endmacro

