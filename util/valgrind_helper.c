#include <valgrind/valgrind.h>
#include <stdio.h>

void* HEAP_POOL = 0;

void MK_POOL( void* pool ) {
    HEAP_POOL = pool;
    VALGRIND_CREATE_MEMPOOL( pool, 8, 0 );
}

void ALLOC( void* addr, long long int size ) {
    VALGRIND_MEMPOOL_ALLOC( HEAP_POOL, addr, size);
}

void FREE( void* addr ) {
    VALGRIND_MEMPOOL_FREE( HEAP_POOL, addr );
}

void TRIM( void* addr, long long int size ) {
    VALGRIND_MEMPOOL_TRIM( HEAP_POOL, addr, size );
}
