#include <unistd.h>
int main() {
    const char msg[] = "Hello, world!\n";
    write(1, msg, sizeof(msg) - 1);
    return 0;
}
