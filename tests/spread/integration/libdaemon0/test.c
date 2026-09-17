/* Exercises the core libdaemon modules: dlog, dpid, dsignal, dnonblock and the
 * dfork/retval daemonizing path. Exits non-zero with a distinct code per
 * failure so a chroot run pinpoints which part of the library broke. */

#include <libdaemon/dfork.h>
#include <libdaemon/dlog.h>
#include <libdaemon/dnonblock.h>
#include <libdaemon/dpid.h>
#include <libdaemon/dsignal.h>

#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#define PID_FILE "/tmp/libdaemon-test.pid"

static const char *pid_file_proc(void) {
    return PID_FILE;
}

/* dlog: log to stdout so the caller can grep the message. Flush before the
 * daemon_fork() test so the forked child cannot duplicate the buffer. */
static int test_log(void) {
    daemon_log_ident = "libdaemon-test";
    daemon_log_use = DAEMON_LOG_STDOUT;
    daemon_log(LOG_INFO, "dlog works");
    fflush(stdout);
    return 0;
}

/* dpid: create a PID file, read our own PID back out, then remove it. */
static int test_pid_file(void) {
    daemon_pid_file_ident = "libdaemon-test";
    daemon_pid_file_proc = pid_file_proc;

    if (daemon_pid_file_create() < 0)
        return 2;
    if (daemon_pid_file_is_running() != getpid())
        return 3;
    if (daemon_pid_file_remove() < 0)
        return 4;
    if (daemon_pid_file_is_running() >= 0)
        return 5;
    return 0;
}

/* dsignal: queue a signal through the library's pipe and read it back. */
static int test_signal(void) {
    if (daemon_signal_init(SIGUSR1, 0) < 0)
        return 6;
    if (daemon_signal_fd() < 0)
        return 7;
    if (raise(SIGUSR1) != 0)
        return 8;
    if (daemon_signal_next() != SIGUSR1)
        return 9;
    daemon_signal_done();
    return 0;
}

/* dnonblock: flip O_NONBLOCK on a pipe end and confirm it stuck. */
static int test_nonblock(void) {
    int fds[2];

    if (pipe(fds) < 0)
        return 10;
    if (daemon_nonblock(fds[0], 1) < 0)
        return 11;
    if (!(fcntl(fds[0], F_GETFL) & O_NONBLOCK))
        return 12;
    if (daemon_nonblock(fds[0], 0) < 0)
        return 13;
    if (fcntl(fds[0], F_GETFL) & O_NONBLOCK)
        return 14;
    close(fds[0]);
    close(fds[1]);
    return 0;
}

/* dfork: daemonize, have the daemon report success over the retval channel. */
static int test_fork(void) {
    pid_t pid;

    if (daemon_retval_init() < 0)
        return 15;

    if ((pid = daemon_fork()) < 0) {
        daemon_retval_done();
        return 16;
    }

    if (pid == 0) {
        /* Daemon process: detached from the terminal, reports back and exits. */
        daemon_retval_send(42);
        _exit(0);
    }

    if (daemon_retval_wait(20) != 42)
        return 17;
    return 0;
}

int main(void) {
    int rc;

    if ((rc = test_log()) != 0)
        return rc;
    if ((rc = test_pid_file()) != 0)
        return rc;
    if ((rc = test_signal()) != 0)
        return rc;
    if ((rc = test_nonblock()) != 0)
        return rc;
    if ((rc = test_fork()) != 0)
        return rc;

    return 0;
}
