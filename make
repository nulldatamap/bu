#!/bin/bash

nasm -felf64 l0.asm -g
ld l0.o -obin/l0
rm l0.o
