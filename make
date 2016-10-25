#!/bin/bash


m_file="$2"

function run {
    if [ -z "$m_file" ]
    then
        ./bin/l0
    else
        cat "$m_file" | ./bin/l0
    fi
}

if [ "$1" == "regs" ]
then
    printf "Preserved:\\n\
  rbx, rsp, rbp, r12, r13, r14, r15\\n\
\\n\
Scratch:\\n\
  rax, rdi, rsi, rdx, rcx, r8, r9, r10, r11\\n"
  exit 0
fi

if [ "$1" == "deps" ]
then
    cd src
    nasm -E l0.asm | rg "^ *((([^.][a-zA-Z0-9_]*):)|call ([a-zA-Z0-9_]*))" -r \
    "\$2\$4" | ../gg.exe | dot -Tpng > ../deps.png
    exit 0
fi

opts=""
valc=""
if [ "$1" == "valgrind" ]
then
    opts="-DVALGRIND"
    valc="valgrindhelper.o"
elif [ "$1" == "analyse" ]
then
    opts="-DANALYSE"
fi

cd src
nasm -felf64 -g l0.asm $opts
cd ..

if [ "$1" == "valgrind" ]
then
    gcc -c util/valgrind_helper.c -ovalgrindhelper.o -fno-stack-protector
fi

ld src/l0.o $valc -obin/l0

if [ "$1" == "valgrind" ]
then
    # Extract symbol table inforation
    objdump -t ./bin/l0 |\
    rg "([\da-f]{16}) l {7}\\.text\\t[\da-f]{16} (.+)" -r "\$1 \$2" > ./bin/syms

    valgrind ./bin/l0 2>&1 >/dev/null | ./util/memchecl.exe
elif [ "$1" == "analyse" ]
then
    run > memdump
    ./util/ad.py
elif [ "$1" == "run" ]
then
    run
fi