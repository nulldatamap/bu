section .text

; ============================== The Algorithm =================================
; This memory allocation algorithm is a basic one. Memory is allocated in 
; blocks. A block consist of a header which is laid out like this:
;
; |<------------------------- 64bit Word Header -------------------------->|                                     
; [LLLLLLLL LLLLLLLL LLLLLLLL LLLLLLLL LLLLLLLL LLLLLLLL LLLLLLLL LLLLLLL|F]
;  ^      ^        ^        ^        ^        ^        ^        ^         ^
;  0      7        15       23       31       39       47       55        63
;
; bit | name
; 63  | F   : Free flag
; 0-62| L   : Length field
;
; So a header consists of a free flag and a length field. If the free flag is 
; set then the allocator is allowed to claim and/or split the block for a new
; allocation. The length field is the amount of space allocated for the block
; which is located after the header.
; 
; The algorithm stores the address of the block with the lowest address that's
; marked as free ( LFB: lowest free block ). If there is none, that value will
; be the end of the address space.
;
; When allocating the algorithm will check if there is an LFB, if not it's 
; create a new block at the end of the address space by calling the `brk` 
; syscall. If the is an LFB available, the length of it is checked. If the size of
; the block is greater or equal to the requested allocation size, it's marked
; for allocation. If LFB doesn't fit the requested allocation size, the 
; allocator will iterate through all the blocks after the LFB until it either
; finds a block with fits the requested allocation size or reached the end of 
; the address space. If it reached the end of the address space, a new block is
; created at the end of the address space.
;
; If a previously allocated block - marked as free - is selected for a new 
; allocation, it's size is compared with the requested allocation size. If there
; is enough space left ( the length of two headers, 16 bytes ) then a new free
; block is created behind the newly allocated one with the remaining size. If 
; the free block has less than those 16 bytes left, those bytes are likely never
; to be used for a new allocation and therefore just becomes a part of the new
; allocation ( which means we've actually claimed more memory requested for the 
; allocation ). The length of the new block is written down in the header and 
; the free flag is unset.
; 
; Freeing memory simply consists of setting the free flag of the specified 
; allocation and updating the LFB if the address of the free'ed block is lower
; than the current LFB. 

; Just a 64bit length field
MEMORY_BLOCK_HEADER_SIZE equ 8
; A block is not worth being split if the remaining size is less than
; a header + 8 bytes
MEMORY_BLOCK_MIN_SIZE    equ 16

; init_alloc () int
init_malloc:
  ; sys_brk
  mov rax, 12
  ; addr = 0 (INVALID)
  mov rdi, 0
  syscall
  mov [addr_space_end], rax
  mov [lowest_free_addr], rax
  mov [addr_space_start], rax
  ret

; malloc ( int size ) ptr
malloc:
  push rbx
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
  push r8
  push r10
  call _search_for_free_block
  pop r10
  pop r8

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
  sub rax, r10
  cmp rax, MEMORY_BLOCK_MIN_SIZE
  jb .takeover_entire_block
  ; If there's enough space left, we split the block by writing a new header
  ; at the end of the to-be allocation
  ; Set rcx the new new block's origin
  lea rcx, [rbx + MEMORY_BLOCK_HEADER_SIZE]
  add rcx, r10
  ; Set it's size to be the remaining size minus the header size and set
  ; free flag in the block header
  sub rax, MEMORY_BLOCK_HEADER_SIZE
  or rax, r8
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
  push r10
  call _search_for_free_block
  pop r10
  mov [lowest_free_addr], rax

.allocate_block:
  ; Write the size ( and unset the free flag ) into the header
  mov [rbx], r10
  ; Return the start of the address space beyond the header
  lea rax, [rbx + MEMORY_BLOCK_HEADER_SIZE]
  pop rbx
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
  pop rbx
  ret

.failed:
  mov rax, 0
  pop rbx
  ret

; _search_for_free_block ( int size, ptr start ) ptr
_search_for_free_block:
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
  ret
  
.load_next_block:
  ; Load the block size and find the next block's offset
  add rbx, MEMORY_BLOCK_HEADER_SIZE
  add rsi, rbx
  ; Check if that offset is the end of the address space
  cmp rsi, [addr_space_end]
  jne .check_block
  mov rax, rsi
  ; Stop checking the blocks if we've reached the end
  pop rbx
  ret

; free ( ptr addr ) int
free:
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
  mov r9, rax
  or r9, r8
  mov [rdi], r9
  ; Return the length which is stored in rax
  ret

.fail:
  ; If the address is already free return zero
  mov rax, 0
  ret

; Updates the status variables: allocated_bytes, used_bytes, free_bytes
; returns allocated bytes
; mem_stat () int
mem_stat:
  ; Load the starting address
  mov rsi, [addr_space_start]
  mov r8, 1 << 63
  ; Use r9 for used bytes
  mov r9, 0
  ; And r10 or free bytes
  mov r10, 0
  mov rcx, [addr_space_end]

.count_block:
  ; Check if these bytes or free or not
  mov rax, [rsi]
  test rax, r8
  jnz .count_free_bytes
  ; If not count them as used bytes
  add r9, rax
  jmp .next_block

.count_free_bytes:
  xor rax, r8
  add r10, rax

.next_block:
  ; Then get the next block's address
  add rsi, rax
  add rsi, MEMORY_BLOCK_HEADER_SIZE
  ; Check if we've reached the end 
  cmp rsi, rcx
  je .finish
  jmp .count_block

.finish:
  mov [used_bytes], r9
  mov [free_bytes], r10

  mov rax, [addr_space_end]
  sub rax, [addr_space_start]
  mov [allocated_bytes], rax
  ret

section .bss
alignb 8

lowest_free_addr resb 8
addr_space_start resb 8
addr_space_end   resb 8

allocated_bytes  resb 8
used_bytes       resb 8
free_bytes       resb 8


