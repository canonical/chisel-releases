        .file   "hello.c"
        .abiversion 2
        .section        .rodata
.LC0:
        .string "Hello world!"

        .text
        .align 2
        .globl  main
        .type   main,@function
main:
.LFB0:
        .cfi_startproc
.LCF0:
0:      addis   2,12,.TOC.-0b@ha
        addi    2,2,.TOC.-0b@l
        .localentry main,.-main
        mflr    0
        std     0,16(1)
        stdu    1,-32(1)
        .cfi_def_cfa_offset 32
        .cfi_offset 65,16

        addis   3,2,.LC0@toc@ha
        addi    3,3,.LC0@toc@l
        bl      puts
        nop

        li      3,0

        addi    1,1,32
        ld      0,16(1)
        mtlr    0
        blr
        .cfi_endproc
.LFE0:
        .size   main,.-main
        .ident  "GCC: (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0"
        .section .note.GNU-stack,"",@progbits
