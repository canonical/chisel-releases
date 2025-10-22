#include <everything/answer.h>

int main() {
    #ifdef ANSWER
        return 42;
    #else
        return 1;
    #endif
}
