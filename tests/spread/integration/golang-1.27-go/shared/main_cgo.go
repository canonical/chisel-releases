package main

/*
#include <stdio.h>

void hello_from_c() {
    printf("Hello from C!\n");
}
*/
import "C"

func main() {
	C.hello_from_c()
	C.fflush(C.stdout)
}
