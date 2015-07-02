#!/bin/bash

cd src
nasm -felf64 l0.asm -g
cd ..
ld src/l0.o -obin/l0
	rm src/l0.o

