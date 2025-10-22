#include <everything/answer.h>

int main() {
    #ifdef ANSWER
        return ANSWER;
    #else
        return 1;
    #endif
}
