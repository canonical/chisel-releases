#include <stdio.h>
#include <nethost.h>

int main(void)
{
    char_t path[4096];
    size_t size = sizeof(path) / sizeof(char_t);
    int rc = get_hostfxr_path(path, &size, NULL);
    if (rc != 0) {
        printf("get_hostfxr_path failed: 0x%x\n", (unsigned int)rc);
        return 1;
    }
    printf("hostfxr: %s\n", path);
    return 0;
}
