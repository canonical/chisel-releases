#ifndef TEST_STD_H
#define TEST_STD_H

typedef struct {
    int passed;
    const char* message;
} TestResult;

typedef struct {
    const char* name;
    void (*test_func)(TestResult* result);
} TestCase;

void check_arithmetic(TestResult* result);
void check_file_io(TestResult* result);
void* thread_func(void* arg);
void check_concurrency(TestResult* result);
void check_memory(TestResult* result);
void check_time(TestResult* result);
void check_env(TestResult* result);
void check_atomic(TestResult* result);
void check_process_control(TestResult* result);
void check_signals(TestResult* result);

#endif // TEST_STD_H