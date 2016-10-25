
struc ElfHeader
    .magic    resb 4
    .bit_mode resb 1
    .endian   resb 1
    .version  resb 1
    .os_abi   resb 1
    resb 8
endstruc
