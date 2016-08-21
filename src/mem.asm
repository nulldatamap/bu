section .text


; Just a 64bit length field
MEMORY_BLOCK_HEADER_SIZE equ 8
; A block is not worth being split if the remaining size is less than
; a header + 8 bytes
MEMORY_BLOCK_MIN_SIZE    equ 16

; initalloc () int
initalloc:
  ; sys_brk
  mov rax, 12
  ; addr = 0 (INVALID)
  mov rdi, 0
  syscall
  mov [addr_space_end], rax
  mov qword [lowest_free_addr], rax
  ret

; balloc ( int size ) ptr
balloc:
  ; Store the base size in r10
  mov r10, rdi
  ; Store the free flag mask for later
  mov r8, 1 << 63
  ; If the lowest free address is the end of the address space then we should
  ; just allocate at the end of the address space
  mov rbx, [lowest_free_addr]
  mov rax, [addr_space_end]
  cmp rax, rbx
  je .alloc_at_end

  ; Check if the lowest free address block has enough space
  mov rax, [rbx]
  xor rax, r8
  cmp rax, rdi
  jae .alloc_at_rbx
  ; Else search for a fitting freed block if any
  
  ; Start searching after the last known lowest free block
  mov rsi, rbx
  call _search_for_free_block

  mov rbx, rax
  mov rax, [addr_space_end]
  cmp rax, rbx
  ; Allocate at the end if no free block was found
  je .alloc_at_end
  ; Otherwise allocate at the found block
.alloc_at_rbx:
  ; Check if there's space left for a new block after allocation the needed
  ; amount of space in the left half of this block
  mov rax, [rbx]
  ; Discard the free flag from the size qword
  xor rax, r8
  sub rax, rdi
  cmp rax, MEMORY_BLOCK_MIN_SIZE
  jb .takeover_entire_block
  ; If there's enough space left, we split the block by writing a new header
  ; at the end of the to-be allocation
  ; Set rcx the new new block's origin
  lea rcx, [rbx + MEMORY_BLOCK_HEADER_SIZE]
  add rcx, rdi
  ; Set it's size to be the remaining size minus the header size and set
  ; free flag in the block header
  sub rax, MEMORY_BLOCK_HEADER_SIZE
  and rax, r8
  mov [rcx], rax
  ; Check if the origin of this allocation was the lowest free address space
  cmp rbx, [lowest_free_addr]
  jne .skip_set_lowest_free_to_split_block
  ; Set the new lowest free address to the address of the newly split block
  mov [lowest_free_addr], rcx
  
.skip_set_lowest_free_to_split_block:
  jmp .allocate_block
  
.takeover_entire_block:
  ; If the block is too small to be split, change the allocation size to the 
  ; block's original size
  mov r10, [rbx]
  xor r10, r8
  ; If we've just taken up a whole block and this was the lowest free block
  cmp rbx, [lowest_free_addr]
  jne .allocate_block
  ; Then we must find the new lowest free block
  
  ; Search for any block size
  mov rdi, 0
  ; and search after this block
  mov rsi, r10
  add rsi, rbx
  call _search_for_free_block
  mov [lowest_free_addr], rax

.allocate_block:
  ; Write the size ( and unset the free flag ) into the header
  mov [rbx], r10
  ; Return the start of the address space beyond the header
  lea rax, [rbx + MEMORY_BLOCK_HEADER_SIZE]
  ret
  
.alloc_at_end:
  ; Move the address space end by MEMORY_BLOCK_HEADER_SIZE + allocation size 
  add rdi, MEMORY_BLOCK_HEADER_SIZE
  add rdi, [addr_space_end]
  mov rax, 12
  syscall
  
  ; Let rbx hold the start of the new allocation and old end of the address space
  mov rbx, [addr_space_end]

  ; If the address space hasn't moved, then do the same >:^S
  cmp rax, rbx
  je .failed

  ; Update the end of the address space variable
  mov [addr_space_end], rax
  ; If the lowest free address previously was at the end of the address space
  mov rdx, [lowest_free_addr]
  cmp rdx, rbx
  jne .skip_lowest_free_addr_update
  ; Then update it to still be
  mov [lowest_free_addr], rax

.skip_lowest_free_addr_update:

  ; Write the address size into the block header
  mov qword [rbx], r10

  ; Return the start of the address space beyond the header
  lea rax, [rbx + MEMORY_BLOCK_HEADER_SIZE]
  ret

.failed:
  mov rax, 0
  ret

; _search_for_free_block ( int size, ptr start ) ptr
_search_for_free_block:
  push r10
  push rcx
  push rbx
  ; Store the size
  mov r10, rdi
  ; Store the free flag mask for later
  mov rcx, 1 << 63

.check_block:
  ; Load the current header
  mov rbx, [rsi]
  ; Check for the free flag
  test rbx, rcx
  jz .load_next_block
  ; Check if the size is big enough
  xor rbx, rcx
  cmp rbx, rdi
  jb .load_next_block
  ; We've found a match
  mov rax, rsi
  pop rbx
  pop rcx
  pop r10
  ret
  
.load_next_block:
  ; Load the block size and find the next block's offset
  mov rbx, [rsi]
  add rbx, MEMORY_BLOCK_HEADER_SIZE
  add rsi, rbx
  ; Check if that offset is the end of the address space
  cmp rsi, [addr_space_end]
  jne .check_block
  mov rax, rsi
  ; Stop checking the blocks if we've reached the end
  pop rbx
  pop rcx
  pop r10
  ret

; bfree ( ptr addr ) int
bfree:
  ; Store the free flag mask
  mov r8, 1 << 63
  ; Get the header of the allocation
  sub rdi, MEMORY_BLOCK_HEADER_SIZE
  ; Check if this address is already free
  mov rax, [rdi]
  test rax, r8
  jnz .fail
  ; Check if this address is lower than the lowest free address
  cmp rdi, [lowest_free_addr]
  jae .skip_lowest_free_addr_update
  ; Then update the last free address
  mov [lowest_free_addr], rdi

.skip_lowest_free_addr_update:

  ; Set the free flag
  mov rbx, rax
  or rbx, r8
  mov [rdi], rbx
  ; Return the length which is stored in rax
  ret

.fail:
  ; If the address is already free return zero
  mov rax, 0
  ret

section .bss
alignb 8
lowest_free_addr resb 8
addr_space_end   resb 8


