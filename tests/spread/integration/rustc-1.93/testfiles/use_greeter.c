#include <stdio.h>

extern const char* greet(const char* who);

int main() {
    const char* message = greet("C");
    printf("%s\n", message);
    return 0;
}
