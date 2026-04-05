#ifndef HL_ALLOCATOR_H
#define HL_ALLOCATOR_H

#include "hl.h"

#ifdef __cplusplus
extern "C" {
#endif

// ========== 常量定义（gc.c 中没有的）==========
#define GC_PARTITIONS       9
#define GC_ALL_PAGES        (GC_PARTITIONS << PAGE_KIND_BITS)

// ========== 类型定义（gc.c 中没有的）==========
typedef unsigned short fl_cursor;

typedef struct {
    fl_cursor pos;
    fl_cursor count;
} gc_fl;

typedef struct _gc_freelist {
    int current;
    int count;
    int size_bits;
    gc_fl *data;
} gc_freelist;

#define SIZES_PADDING 8

typedef struct {
    int block_size;
    unsigned char size_bits;
    unsigned char need_flush;
    short first_block;
    int max_blocks;
    gc_freelist free;
    unsigned char *sizes;
    char sizes_ref[SIZES_PADDING];
} gc_allocator_page_data;

// ========== 回调函数类型 ==========
typedef void (*gc_page_iterator)(gc_pheader *, int);
typedef void (*gc_block_iterator)(void *, int);

// ========== 注意：不要声明 gc.c 中已经定义的 static 变量和函数 ==========
// gc_pheader、hl_gc_page_map、gc_level1_null、gc_flags 等都在 gc.c 中定义为 static
// 所以这里不要 extern 它们

// ========== allocator.c 需要的函数声明（这些函数在 gc.c 中是 static，但 allocator.c 需要）==========
// 实际上 allocator.c 需要的 gc_alloc_page、gc_free_page 等也在 gc.c 中定义为 static
// 但由于 allocator.c 和 gc.c 一起编译，static 函数在同一文件中可见
// 所以这里不需要声明

#ifdef __cplusplus
}
#endif

#endif // HL_ALLOCATOR_H