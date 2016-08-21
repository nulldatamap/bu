# BU
## What is it?
__BU__ is a little project and challenge for myself. The point is to build a set
of programming languages, starting from the **B**uttom **U**p. That means starting
with assembly and no libraries, just me, my assembler and the OS. From that, I'm
going to build up "level" of abstractions.

## How to run it
This only runs on x86_64 linux.

It requires `nasm` to assemble and `ld` to link.

Build with `./make`

## Goals
### Level 0: `l0`
The goal for level 0 is to make a simple low-level programming language ( like C )
as a basis for level 1.

* [x] Basic terminal input and out

* [x] A state machine for tokenizing

* [x] My own memory allocator

* [ ] A parser + AST builder

* [ ] AST validator

* [ ] A simple executable generator


### Level 1: `l1`
_TODO_