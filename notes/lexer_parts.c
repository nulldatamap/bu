// Our example program:

main () int {
  stdout_write( "Hello, world!\x0A".chars, "Hello, world!\x0A".len )
  return 0
}

Character kind:
I [a-zA-Z_]
H [a-fA-F]
D [0-9]
...
Literals
...
C [^\n']
S [^\n"]

// Needed tokens
IDENT   : [a-zA-Z_]+
INTEGER : -?\d+
FLOAT   : 
CHAR    : '(\\\\|\\x[0-9a-fA-F]{2}|[^\n'])'
STRING  : "(\\\\|\\x[0-9a-fA-F]{2}|[^\n"])"
OPAREN  : 
CPARAN  : 
OBRACE  : 
CBRACE  : 
DOT     : 
COMMA   : 

