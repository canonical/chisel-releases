#include <iproute2/bpf_elf.h>
#include <stdio.h>
#include <string.h>
// #include <linux/bpf.h>

int main(void) {
    struct bpf_elf_map map;
    memset(&map, 0, sizeof(map));
    map.type      = 1; /* BPF_MAP_TYPE_HASH */
    map.size_key  = sizeof(__u32);
    map.size_value = sizeof(__u32);
    map.max_elem  = 1024;
    map.pinning   = PIN_GLOBAL_NS;

    printf("PIN_GLOBAL_NS: %u\n", PIN_GLOBAL_NS);
    printf("PIN_NONE: %u\n", PIN_NONE);
    printf("PIN_OBJECT_NS: %u\n", PIN_OBJECT_NS);
    printf("ELF_MAX_MAPS: %u\n", ELF_MAX_MAPS);
    printf("ELF_MAX_LICENSE_LEN: %u\n", ELF_MAX_LICENSE_LEN);
    printf("ELF_SECTION_LICENSE: %s\n", ELF_SECTION_LICENSE);
    printf("ELF_SECTION_MAPS: %s\n", ELF_SECTION_MAPS);
    printf("ELF_SECTION_PROG: %s\n", ELF_SECTION_PROG);
    printf("ELF_SECTION_CLASSIFIER: %s\n", ELF_SECTION_CLASSIFIER);
    printf("ELF_SECTION_ACTION: %s\n", ELF_SECTION_ACTION);
    
    printf("Hello, BPF ELF!\n");
    return 0;
}