#include "test_std.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <errno.h>
#include <assert.h>
#include <stdint.h>
#include <limits.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdalign.h>
#include <signal.h>


int main() {
    printf("Running basic standard library checks...\n");
    TestCase tests[] = {
        {"Arithmetic", check_arithmetic},
        {"File I/O", check_file_io},
        {"Concurrency", check_concurrency},
        {"Memory", check_memory},
        {"Time", check_time},
        {"Environment Variables and Args", check_env},
        {"Atomics", check_atomic},
        {"Process Control", check_process_control},
        {"Signals", check_signals},
    };

    int overall_result = 1;
    for (int i = 0; i < sizeof(tests)/sizeof(tests[0]); i++) {
        TestResult result;
        tests[i].test_func(&result);
        if (result.passed) {
            printf("Test %d (%s) passed\n", i + 1, tests[i].name);
        } else {
            printf("Test %d (%s) failed: %s\n", i + 1, tests[i].name, result.message);
            overall_result = 0;
        }
    }

    if (!overall_result) {
        printf("Some tests failed.\n");
        return 1;
    } else {
        printf("\nAll basic checks passed!\n");
        return 0;
    }
}

void check_arithmetic(TestResult* result) {
    if (10 + 5 != 15) { result->passed = 0; result->message = "Integer addition failed"; return; }
    if (10 - 5 != 5) { result->passed = 0; result->message = "Integer subtraction failed"; return; }
    if (10 * 5 != 50) { result->passed = 0; result->message = "Integer multiplication failed"; return; }
    if (10 / 5 != 2) { result->passed = 0; result->message = "Integer division failed"; return; }
    if (10 % 3 != 1) { result->passed = 0; result->message = "Integer modulus failed"; return; }

    double a = 10.0;
    double b = 5.0;
    if (a / b != 2.0) { result->passed = 0; result->message = "Floating point division failed"; return; }

// we have infinity only in C23
#ifdef INFINITY
    double c = 1.0;
    double d = 0.0;
    if (!(c / d == INFINITY)) { result->passed = 0; result->message = "Division by zero did not yield infinity"; return; }
#endif

    result->passed = 1;
    result->message = "Arithmetic tests passed";
}

void check_file_io(TestResult* result) {
    const char* filename = "test_file.txt";
    const char* test_data = "Hello from C file I/O!";
    FILE* file = fopen(filename, "w");
    if (!file) { result->passed = 0; result->message = "File creation failed"; return; }
    if (fwrite(test_data, 1, strlen(test_data), file) != strlen(test_data)) {
        fclose(file);
        result->passed = 0; result->message = "File write failed"; return;
    }
    fclose(file);
    file = fopen(filename, "r");
    if (!file) { result->passed = 0; result->message = "File open failed"; return; }
    char buffer[256];
    size_t read_bytes = fread(buffer, 1, sizeof(buffer)-1, file);
    if (read_bytes <= 0) {
        fclose(file);
        result->passed = 0; result->message = "File read failed"; return;
    }
    buffer[read_bytes] = '\0';
    fclose(file);
    if (strcmp(buffer, test_data) != 0) { result->passed = 0; result->message = "File contents do not match"; return; }
    if (remove(filename) != 0) { result->passed = 0; result->message = "File removal failed"; return; }
    result->passed = 1;
    result->message = "File I/O tests passed";
}

void* thread_func(void* arg) {
    int* counter = (int*)arg;
    for (int i = 0; i < 100000; i++) {
        __atomic_fetch_add(counter, 1, __ATOMIC_SEQ_CST);
    }
    return NULL;
}

void check_concurrency(TestResult* result) {
    pthread_t threads[10];
    int counter = 0;
    for (int i = 0; i < 10; i++) {
        if (pthread_create(&threads[i], NULL, thread_func, &counter) != 0) {
            result->passed = 0; result->message = "Thread creation failed"; return;
        }
    }
    for (int i = 0; i < 10; i++) {
        if (pthread_join(threads[i], NULL) != 0) {
            result->passed = 0; result->message = "Thread join failed"; return;
        }
    }
    if (counter != 1000000) { result->passed = 0; result->message = "Counter value incorrect"; return; }
    result->passed = 1;
    result->message = "Concurrency tests passed";
}

void check_memory(TestResult* result) {
    if (sizeof(int32_t) != 4) { result->passed = 0; result->message = "size_of::<int32_t>() failed"; return; }
    if (sizeof(double) != 8) { result->passed = 0; result->message = "size_of::<double>() failed"; return; }
    if (alignof(int32_t) != 4) { result->passed = 0; result->message = "align_of::<int32_t>() failed"; return; }
    if (alignof(double) != 8) { result->passed = 0; result->message = "align_of::<double>() failed"; return; }

    struct AlignedStruct {
        char a;
        int32_t b;
    };
    if (sizeof(struct AlignedStruct) != 8) { result->passed = 0; result->message = "size_of::<AlignedStruct>() failed"; return; }

    result->passed = 1;
    result->message = "Memory tests passed";
}

void check_time(TestResult* result) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    usleep(50000); // sleep for 50 milliseconds
    clock_gettime(CLOCK_MONOTONIC, &end);
    long elapsed_ms = (end.tv_sec - start.tv_sec) * 1000 + (end.tv_nsec - start.tv_nsec) / 1000000;
    if (elapsed_ms < 50) { result->passed = 0; result->message = "Sleep duration incorrect"; return; }

    struct timeval tv;
    gettimeofday(&tv, NULL);
    if (tv.tv_sec < 1700000000) { result->passed = 0; result->message = "System time is likely incorrect or too far in the past"; return; }

    result->passed = 1;
    result->message = "Time tests passed";
}

void check_env(TestResult* result) {
    const char* test_key = "C_TEST_VAR";
    const char* test_val = "c_test_value";
    if (setenv(test_key, test_val, 1) != 0) { result->passed = 0; result->message = "Failed to set env var"; return; }
    char* var_val = getenv(test_key);
    if (!var_val || strcmp(var_val, test_val) != 0) { result->passed = 0; result->message = "Failed to get correct environment variable value"; return; }

    int argc = 1;
    char* argv[] = {"program_name", NULL};
    if (argc < 1) { result->passed = 0; result->message = "Command line arguments check failed"; return; }

    result->passed = 1;
    result->message = "Environment tests passed";
}

void check_atomic(TestResult* result) {
    atomic_int atomic_counter = 0;
    atomic_fetch_add(&atomic_counter, 1);
    if (atomic_load(&atomic_counter) != 1) { result->passed = 0; result->message = "Atomic increment failed"; return; }
    atomic_fetch_sub(&atomic_counter, 1);
    if (atomic_load(&atomic_counter) != 0) { result->passed = 0; result->message = "Atomic decrement failed"; return; }
    result->passed = 1;
    result->message = "Atomic tests passed";
}

void check_process_control(TestResult* result) {
    pid_t pid = fork();
    if (pid < 0) { result->passed = 0; result->message = "Fork failed"; return; }
    if (pid == 0) {
        // Child process
        exit(42);
    } else {
        // Parent process
        int status;
        if (waitpid(pid, &status, 0) < 0) { result->passed = 0; result->message = "Waitpid failed"; return; }
        if (WIFEXITED(status)) {
            int exit_status = WEXITSTATUS(status);
            if (exit_status != 42) { result->passed = 0; result->message = "Child exit status incorrect"; return; }
        } else {
            result->passed = 0; result->message = "Child did not exit normally"; return;
        }
    }
    result->passed = 1;
    result->message = "Process control tests passed";
}

void check_signals(TestResult* result) {
    // Simple signal handling test
    struct sigaction sa;
    sa.sa_handler = SIG_IGN; // Ignore the signal
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGUSR1, &sa, NULL) != 0) { result->passed = 0; result->message = "Sigaction failed"; return; }

    // Send the signal to self
    if (raise(SIGUSR1) != 0) { result->passed = 0; result->message = "Raise signal failed"; return; }

    result->passed = 1;
    result->message = "Signal handling tests passed";
}
