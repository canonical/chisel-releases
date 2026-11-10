#include <stdio.h>
#include <stddef.h>
#include <security/pam_appl.h>

int main(void) {
    pam_handle_t *handle = NULL;
    struct pam_conv conv = {};
    int status = pam_start("hello-pam", "user", &conv, &handle);
    if (status != PAM_SUCCESS) {
        fprintf(stderr, "PAM error: %s: %s\n", "pam_start", pam_strerror(handle, status));
    }

    if (status == PAM_SUCCESS) {
        status = pam_authenticate(handle, 0);
        if (status != PAM_SUCCESS) {
            fprintf(stderr, "PAM error: %s: %s\n", "pam_authenticate", pam_strerror(handle, status));
        }
    }

    if (status == PAM_SUCCESS) {
        puts("PAM says: Hello, world!");
    }

    if (handle != NULL) {
        status = pam_end(handle, status);
        if (status != PAM_SUCCESS) {
            fprintf(stderr, "PAM error: %s: %s\n", "pam_end", pam_strerror(handle, status));
        }
    }

    return 0;
}

