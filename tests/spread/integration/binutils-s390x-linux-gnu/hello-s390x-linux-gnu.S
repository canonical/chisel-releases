        .file   "hello.c"
        .text
        .section .rodata
.LC0:
        .string "Hello world!"
        .text
        .globl  main
        .type   main,@function
main:
.LFB0:
        .cfi_startproc
        stmg    %r14,%r15,112(%r15)
        .cfi_offset 14,-16
        .cfi_offset 15,-8
        aghi    %r15,-160
        .cfi_def_cfa_offset 160

        larl    %r2,.LC0
        brasl   %r14,puts@PLT

        lghi    %r2,0

        aghi    %r15,160
        lmg     %r14,%r15,112(%r15)
        br      %r14
        .cfi_endproc
.LFE0:
        .size   main,.-main
        .ident  "GCC: (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0"
        .section .note.GNU-stack,"",@progbits
