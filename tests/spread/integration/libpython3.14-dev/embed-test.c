#include <Python.h>

int main(void) {
    Py_Initialize();
    if (!Py_IsInitialized()) {
        return 1;
    }
    int result = PyRun_SimpleString("assert sum([20, 22]) == 42");
    return Py_FinalizeEx() < 0 || result != 0;
}
