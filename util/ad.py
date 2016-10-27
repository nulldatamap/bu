#!/usr/bin/python
import struct
BLOCK_FREE = 1
BLOCK_TAKEN = 0

fmt_Vec = "QQQ"
fmt_AST = "<BQQ" + 3 * fmt_Vec

class Heap:
    def __init__( self, base_addr, ram ):
        self.base_addr = base_addr
        self.ram = ram
    
    def load( self, addr, readable ):
        print( ":=  " + hex( addr ) + " / " + hex( addr-self.base_addr ) )
        if addr > self.base_addr + len( self.ram ):
            raise RuntimeError( "Address out of bounds: " + hex( addr ) )
        # print( "Load: 0x{:x} -> 0x{:x}:{}".format( addr, addr-self.base_addr, readable.size ) )
        return readable.read( self.ram[addr-self.base_addr:], self )
    
    def get_data( self, addr, length ):
        print( ".=  " + hex( addr ) + " / " + hex( addr-self.base_addr ) )
        if addr > self.base_addr + len( self.ram ):
            raise RuntimeError( "Address out of bounds: " + hex( addr ) )
        # print( "DLoad: 0x{:x} -> 0x{:x}:{}".format( addr, addr-self.base_addr, length ) )
        return self.ram[addr - self.base_addr:][:length]

class Block:
    def __init__( self, flag, length, data ):
        self.flag = flag
        self.length = length
        self.data = data
    
    def __str__( self ):
        flagstr = "FREE " if self.flag == BLOCK_FREE else ""
        return "Block {}<{} bytes>".format( flagstr, self.length )

class Vec:
    def __init__( self, data, length, capacity, ty=None ):
        self.data = data
        self.length = length
        self.capacity = capacity
        self.ty = ty
    
    size = 24

    @classmethod
    def read( cls, data, heap ):
        (datptr, le, ca) = struct.unpack( "QQQ", data[:cls.size] )
        def v( ty ):
            stride = le / ty.size
            if stride * ty.size != le:
                print( "Invalid stride: {}/{} for {}".format( le % ty.size, ca, ty ) )
            if ty == Stmt:
                print( "[{}] {}/{}".format( le / ty.size, le, ca ) )
            return Vec( [ heap.load( datptr + i * ty.size, ty ) for i in range( 0, le / ty.size ) ], le / ty.size, ca, ty )
        return v

    def __str__( self ):
        return """Vec<{}>( length={}, capacity={} ) {{
    {}
}}""".format( self.ty.__name__.split(".")[-1], self.length, self.capacity, self.data )

class VecString:
    size = 24

    @classmethod
    def read( cls, data, heap ):
        print( "VecString@" + hex( heap.ram.find( data[:cls.size] ) ) )
        (datptr, le, ca) = struct.unpack( "QQQ", data[:cls.size] )
        r = heap.get_data( datptr, le )
        return r

class Byte:
    size = 1
    @classmethod
    def read( cls, data, heap ):
        return data[0]

class Qword:
    size = 8
    @classmethod
    def read( cls, data, heap ):
        return struct.unpack( "Q", data[0:cls.size] )

class Ty:
    def __init__( self, ptr, tyn ):
        self.ty = ptr * "*" + tyn
    
    size = 8 + Vec.size
    
    @classmethod
    def read( cls, data, heap ):
        print( "Ty@" + hex( heap.ram.find( data[:cls.size] ) ) )
        (ptr,) = struct.unpack( "Q", data[:8] )
        return Ty( ptr, VecString.read( data[8:], heap ) )

    def __str__( self ):
        return self.ty

class NameTy:
    size = VecString.size + Ty.size
    @classmethod
    def read( cls, data, heap ):
        nm = VecString.read( data, heap )
        ty = Ty.read( data[VecString.size:], heap )
        return (nm, ty)

class Struct:
    def __init__( self, fields ):
        self.fields = fields
    
    size = Vec.size

    @classmethod
    def read( cls, data, heap ):
        return Struct( Vec.read( data, heap )( NameTy ) )
    
    def __repr__( self ):
        return """{{
{}
}}""".format( "\n    ".join( map( lambda (nm, ty): nm + " " + str( ty ), self.fields.data ) ) )

TYDEF_ALIAS  = 0
TYDEF_STRUCT = 1

class Typedef:
    def __init__( self, name, tykind, ty ):
        self.name = name
        self.ty = ty
    
    size = VecString.size + 1 + Ty.size

    @classmethod
    def read( cls, data, heap ):
        print( "Typedef@" + hex( heap.ram.find( data[:cls.size] ) ) )
        n = VecString.read( data, heap )
        (kind,) = struct.unpack( "B", data[VecString.size:][:1] )
        
        if kind == TYDEF_ALIAS:
            t = Ty.read( data[VecString.size + 1:], heap )
        else:
            t = Struct.read( data[VecString.size + 1:], heap )
        return Typedef( n, kind, t )
    
    def __repr__( self ):
        return "type {} = {}".format( self.name, self.ty )

IntExpr = 0
StrExpr = 1
ChrExpr = 2
NameExpr = 3
FieldExpr = 4
CallExpr = 5
BinExpr = 6
UnaryExpr = 7
CastExpr = 8

class Expr:
    def __init__( self, kind ):
        self.kind = kind
    
    size = 1 + 8 + Ty.size

    @classmethod
    def read( cls, data, heap ):
        (kind,) = struct.unpack( "B", data[0] )
        expr = Expr( kind )
        if kind == IntExpr:
            (expr.value,) = struct.unpack( "Q", data[1:9] )
        elif kind == StrExpr or kind == NameExpr:
            expr.value = VecString.read( data[1:1 + VecString.size], heap )
        elif kind == ChrExpr:
            (expr.value,) = struct.unpack( "c", data[1:2] )
        elif kind == FieldExpr:
            (addr,) = struct.unpack( "Q", data[1:9] )
            expr.subject = heap.load( addr, Expr )
            expr.field = VecString.read( data[1 + 8:], heap )
        elif kind == CallExpr:
            (addr,) = struct.unpack( "Q", data[1:9] )
            expr.callee = heap.load( addr, Expr )
            expr.args = Vec.read( data[9:], heap )( Expr )
        elif kind == BinExpr:
            expr.operator = data[1]
            (left, right) = struct.unpack( "QQ", data[2:18] )
            expr.left = heap.load( left, Expr )
            expr.right = heap.load( right, Expr )
        elif kind == UnaryExpr:
            expr.operator = data[1]
            (oper,) = struct.unpack( "Q", data[2:10] )
            expr.operand = heap.load( oper, Expr )
        elif kind == CastExpr:
            (subj,) = struct.unpack( "Q", data[1:9] )
            expr.subject = heap.load( subj, Expr )
            expr.type = Ty.read( data[9:], heap )
        else:
            raise RuntimeError( "Invalid expression kind: " + str( kind ) )
        
        return expr
    
    def oper_str( self ):
        if self.operator in map( chr, range( 13, 19 ) ):
            return ["==", "!=", "<=", ">=", "&&", "||"][ord(self.operator) - 13]
        else:
            return self.operator

    def __repr__( self ):
        kind = self.kind
        if kind in [ IntExpr, NameExpr ]:
            return str( self.value )
        elif kind in [ StrExpr, ChrExpr ]:
            return self.value.__repr__()
        elif kind == FieldExpr:
            return self.subject.__repr__() + "." + self.field
        elif kind == CallExpr:
            return self.callee.__repr__() + "(" + ",".join( map( str, self.args.data ) ) + ")"
        elif kind == BinExpr:
            rhs = self.right.__repr__()
            if self.right.kind == BinExpr:
                rhs = "(" + rhs + ")" 
            return self.left.__repr__() + " " + self.oper_str() + " " + rhs
        elif kind == UnaryExpr:
            return self.operator + self.operand.__repr__()
        elif kind == CastExpr:
            return self.subject.__repr__() + " as " + str( self.type )

class Letdef:
    def __init__( self, name, ty, value ):
        self.name = name
        self.ty = ty
        self.value = value
    
    size = VecString.size + Ty.size + 1 + Expr.size

    @classmethod
    def read( cls, data, heap ):
        n = VecString.read( data, heap )
        t = Ty.read( data[VecString.size:], heap )
        (d,) = struct.unpack( "B", data[VecString.size + Ty.size][:1] )
        v = None
        if d == 1:
            v = Expr.read( data[VecString.size + Ty.size + 1:], heap )
        return Letdef( n, t, v )
    
    def __repr__( self ):
        return "let {} {}{}".format( self.name, self.ty, "" if self.value == None else " = " + str( self.value ) )

def print_stmts( stmts ):
    return ";\n    ".join( map( str, stmts.data ) )

IfThen = 0
IfElse = 1
IfElif = 2

class If:
    def __init__( self, ifk, cond, then ):
        self.if_kind = ifk
        self.cond = cond
        self.then_block = then
    
    size = 1 + Expr.size + 1 + 2 * Vec.size

    @classmethod
    def read( cls, data, heap ):
        cond = Expr.read( data, heap )
        then = Vec.read( data[Expr.size:], heap )( Stmt )
        (ifk,) = struct.unpack( "B", data[Expr.size + Vec.size:][:1] )
        ifs = If( ifk, cond, then )
        if ifk == IfElse:
            ifs.else_block = Vec.read( data[Expr.size + Vec.size + 1:], heap )( Stmt )
        elif ifk == IfElif:
            (elifs,) = struct.unpack( "Q", data[Expr.size + Vec.size + 1:][:8] )
            ifs.else_block = heap.load( elifs, If )
        return ifs
    
    def __repr__( self ):
        if self.if_kind == IfThen:
            return "if {} {{\n    {}\n}}".format( self.cond.__repr__(), print_stmts( self.then_block ) )
        elif self.if_kind == IfElse:
            return "if {} {{\n    {}\n}} else {{\n    {}\n}}".format( self.cond.__repr__(), print_stmts( self.then_block ), print_stmts( self.else_block ) )
        else:
            return "if {} {{\n    {}\n}} el{}".format( self.cond.__repr__(), print_stmts( self.then_block ), self.else_block.__repr__() )

ExprStmt = 0
DefStmt = 1
RetStmt = 2
IfStmt = 3
AsgnStmt = 4

class Stmt:
    def __init__( self, kind ):
        self.kind = kind

    size = If.size

    @classmethod
    def read( cls, data, heap ):
        (kind,) = struct.unpack( "B", data[0] )
        stmt = Stmt( kind )
        if kind == ExprStmt:
            stmt.expr = Expr.read( data[1:], heap )
        elif kind == DefStmt:
            stmt.defn = Letdef.read( data[1:], heap )
        elif kind == RetStmt:
            stmt.expr = Expr.read( data[1:], heap )
        elif kind == AsgnStmt:
            stmt.lhs = Expr.read( data[1:], heap )
            stmt.rhs = Expr.read( data[1 + Expr.size:], heap )
        elif kind == IfStmt:
            stmt.ifs = If.read( data[1:], heap )
        else:
            raise RuntimeError( "Invalid statement kind: " + str( kind ) )
        return stmt
    
    def __repr__( self ):
        if self.kind == ExprStmt:
            return self.expr.__repr__()
        elif self.kind == DefStmt:
            return self.defn.__repr__()
        elif self.kind == RetStmt:
            return "return " + self.expr.__repr__()
        elif self.kind == AsgnStmt:
            return "{} = {}".format( self.lhs.__repr__(), self.rhs.__repr__() )
        elif self.kind == IfStmt:
            return self.ifs.__repr__()


class Fndef:
    def __init__( self, name, args, retty, body ):
        self.name = name
        self.args = args
        self.return_ty = retty
        self.body = body
    
    size = Vec.size * 3 + Ty.size

    @classmethod
    def read( cls, data, heap ):
        nm = VecString.read( data, heap )

        args = Vec.read( data[VecString.size:], heap )( NameTy )
        rty = Ty.read( data[Vec.size * 2:], heap )
        body = Vec.read( data[Vec.size * 2 + Ty.size:], heap )( Stmt )
        return Fndef( nm, args, rty, body )
    
    def __repr__( self ):
        return """fn {}({}) {} {{
    {}
}}""".format( self.name, ", ".join( map( lambda (x,y): x + " " + str(y), self.args.data ) ), self.return_ty, ";\n    ".join( map( str, self.body.data ) ) )


class AST:
    def __init__( self, err, errmsg, errtok, typs, defs, fns ):
        self.err = err
        self.errmsg = errmsg
        self.errtok = errtok
        self.typedefs = typs
        self.letdefs = defs
        self.fndefs = fns
    
    size = 1 + 8 + 8 + Vec.size * 3

    @classmethod
    def read( cls, data, heap ):
        (e, em, et) = struct.unpack( "<BQQ", data[:17] )

        if e != 0:
            print "Warning: parsing failed, the AST might be broken"
            raw_input()

        ts = Vec.read( data[17:17 + 24], heap )
        ls = Vec.read( data[17 + 24:17 + 48], heap )
        fs = Vec.read( data[17 + 48:17 + 48 + 24], heap )
        return AST( e, em, et, ts( Typedef ), ls( Letdef ), fs( Fndef ) )
    
    def __str__( self ):
        return """AST:
    err: {}
    errmsg: 0x{:x}
    errtok: {}
    typedefs: {}
    letdefs: {}
    fndefs: {}
""".format( self.err, self.errmsg, self.errtok, self.typedefs, self.letdefs, self.fndefs )

with file( "memdump", 'r' ) as f:
    # Skip the trailing newline
    data = f.read()[:-1] 

if len( data ) == 0:
    print( "No data." )
    exit()

(addr_low,) = struct.unpack( "Q", data[:8] )
(addr_high,) = struct.unpack( "Q", data[8:16] )
data = data[16:]

print( "Base addr: " + hex( addr_low ) )

heap = Heap( addr_low, data )

# Read the blocks
offset = 0
blocks = []
while True:
    (block_header,) = struct.unpack( "q", data[offset:offset+8] )
    block_flag = block_header >> 63
    block_length = block_header & ( ~(1 << 63) & 0xFFFFFFFFFFFFFFFF )
    block_data = data[offset+8:offset+8+block_length]
    if len( block_data ) != block_length:
        print( "Error expected block data length of {}, but got: {}".format( len( block_data ), block_lengt ) )
    blocks.append( Block( block_flag, block_length, block_data ) )
    offset += 8+block_length
    
    if len( data[offset:] ) == 0:
        break

for block in blocks:
    print( str( block ) )

print( heap.load( heap.base_addr + 0x8 + 0x8 + blocks[0].length, AST ) )
