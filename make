#!/bin/bash

cd src
nasm -felf64 -g l0.asm
cd ..
ld src/l0.o -obin/l0
rm src/l0.o
