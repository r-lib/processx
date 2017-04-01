
void processx_unix_dummy() { }

#ifndef _WIN32

#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <signal.h>
#include <sys/wait.h>
#include <poll.h>

#include "utils.h"

/* API from R */

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP detached, SEXP windows_verbatim_args,
		   SEXP windows_hide_window, SEXP private, SEXP cleanup);
SEXP processx_wait(SEXP status, SEXP timeout);
SEXP processx_is_alive(SEXP status);
SEXP processx_get_exit_status(SEXP status);
SEXP processx_signal(SEXP status, SEXP signal);
SEXP processx_kill(SEXP status, SEXP grace);
SEXP processx_get_pid(SEXP status);

/* Child list and its functions */

typedef struct processx__child_list_s {
  pid_t pid;
  SEXP status;
  struct processx__child_list_s *next;
} processx__child_list_t;

static processx__child_list_t *child_list = NULL;

static void processx__child_add(pid_t pid, SEXP status);
static void processx__child_remove(pid_t pid);
static processx__child_list_t *processx__child_find(pid_t pid);

void processx__sigchld_callback(int sig, siginfo_t *info, void *ctx);
static void processx__setup_sigchld();
static void processx__remove_sigchld();
static void processx__block_sigchld();
static void processx__unblock_sigchld();

/* Other internals */

static int processx__nonblock_fcntl(int fd, int set);
static int processx__cloexec_fcntl(int fd, int set);
static void processx__child_init(processx_handle_t *handle, int pipes[3][2],
				 char *command, char **args, int error_fd,
				 const char *stdout, const char *stderr,
				 processx_options_t *options);
static void processx__collect_exit_status(SEXP status, int wstat);
static void processx__finalizer(SEXP status);

SEXP processx__make_handle(SEXP private, int cleanup);

/* Define BSWAP_32 on Big Endian systems */
#ifdef WORDS_BIGENDIAN
#if (defined(__sun) && defined(__SVR4))
#include <sys/byteorder.h>
#elif (defined(__APPLE__) && defined(__ppc__) || defined(__ppc64__))
#include <libkern/OSByteOrder.h>
#define BSWAP_32 OSSwapInt32
#elif (defined(__OpenBSD__))
#define BSWAP_32(x) swap32(x)
#elif (defined(__GLIBC__))
#include <byteswap.h>
#define BSWAP_32(x) bswap_32(x)
#endif
#endif

void R_unload_processx(DllInfo *dll) {
  processx__remove_sigchld();
}

static int processx__nonblock_fcntl(int fd, int set) {
  int flags;
  int r;

  do { r = fcntl(fd, F_GETFL); } while (r == -1 && errno == EINTR);
  if (r == -1) { return -errno; }

  /* Bail out now if already set/clear. */
  if (!!(r & O_NONBLOCK) == !!set) { return 0; }

  if (set) { flags = r | O_NONBLOCK; } else { flags = r & ~O_NONBLOCK; }

  do { r = fcntl(fd, F_SETFL, flags); } while (r == -1 && errno == EINTR);
  if (r) { return -errno; }

  return 0;
}

static int processx__cloexec_fcntl(int fd, int set) {
  int flags;
  int r;

  do { r = fcntl(fd, F_GETFD); } while (r == -1 && errno == EINTR);
  if (r == -1) { return -errno; }

  /* Bail out now if already set/clear. */
  if (!!(r & FD_CLOEXEC) == !!set) { return 0; }

  if (set) { flags = r | FD_CLOEXEC; } else { flags = r & ~FD_CLOEXEC; }

  do { r = fcntl(fd, F_SETFD, flags); } while (r == -1 && errno == EINTR);
  if (r) { return -errno; }

  return 0;
}

void processx__write_int(int fd, int err) {
  int dummy = write(fd, &err, sizeof(int));
  (void) dummy;
}

static void processx__child_init(processx_handle_t* handle, int pipes[3][2],
				 char *command, char **args, int error_fd,
				 const char *stdout, const char *stderr,
				 processx_options_t *options) {

  int fd0, fd1, fd2;

  if (options->detached) setsid();

  /* stdin is coming from /dev/null */

  fd0 = open("/dev/null", O_RDONLY);
  if (fd0 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  if (fd0 != 0) fd0 = dup2(fd0, 0);
  if (fd0 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  /* stdout is going into file or a pipe */

  if (!stdout) {
    fd1 = open("/dev/null", O_RDWR);
  } else if (!strcmp(stdout, "|")) {
    fd1 = pipes[1][1];
    close(pipes[1][0]);
  } else {
    fd1 = open(stdout, O_CREAT | O_TRUNC| O_RDWR, 0644);
  }
  if (fd1 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  if (fd1 != 1) fd1 = dup2(fd1, 1);
  if (fd1 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  /* stderr, to file or a pipe */

  if (!stderr) {
    fd2 = open("/dev/null", O_RDWR);
  } else if (!strcmp(stderr, "|")) {
    fd2 = pipes[2][1];
    close(pipes[2][0]);
  } else {
    fd2 = open(stderr, O_CREAT | O_TRUNC| O_RDWR, 0644);
  }
  if (fd2 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  if (fd2 != 2) fd2 = dup2(fd2, 2);
  if (fd2 == -1) { processx__write_int(error_fd, - errno); raise(SIGKILL); }

  processx__nonblock_fcntl(fd0, 0);
  processx__nonblock_fcntl(fd1, 0);
  processx__nonblock_fcntl(fd2, 0);

  execvp(command, args);
  processx__write_int(error_fd, - errno);
  raise(SIGKILL);
}

static void processx__finalizer(SEXP status) {
  processx_handle_t *handle = (processx_handle_t*) R_ExternalPtrAddr(status);
  pid_t pid;
  int wp, wstat;
  SEXP private;

  processx__block_sigchld();

  /* Already freed? */
  if (!handle) goto cleanup;

  pid = handle->pid;

  if (handle->cleanup) {
    /* Do a non-blocking waitpid() to see if it is running */
    do {
      wp = waitpid(pid, &wstat, WNOHANG);
    } while (wp == -1 && errno == EINTR);

    /* Maybe just waited on it? Then collect status */
    if (wp == pid) processx__collect_exit_status(status, wstat);

    /* If it is running, we need to kill it, and wait for the exit status */
    if (wp == 0) {
      kill(pid, SIGKILL);
      do {
	wp = waitpid(pid, &wstat, 0);
      } while (wp == -1 && errno == EINTR);
      processx__collect_exit_status(status, wstat);
    }
  } else {
    /* No SIGCHLD handler for this process */
    processx__child_remove(pid);
  }

  /* Copy over pid and exit status */
  private = R_ExternalPtrTag(status);
  defineVar(install("exited"), ScalarLogical(1), private);
  defineVar(install("pid"), ScalarInteger(pid), private);
  defineVar(install("exitcode"), ScalarInteger(handle->exitcode), private);

  /* Deallocate memory */
  R_ClearExternalPtr(status);
  processx__handle_destroy(handle);

 cleanup:
  processx__unblock_sigchld();
}

SEXP processx__make_handle(SEXP private, int cleanup) {
  processx_handle_t * handle;
  SEXP result;

  handle = (processx_handle_t*) malloc(sizeof(processx_handle_t));
  if (!handle) { error("Out of memory"); }
  memset(handle, 0, sizeof(processx_handle_t));
  handle->waitpipe[0] = handle->waitpipe[1] = -1;

  result = PROTECT(R_MakeExternalPtr(handle, private, R_NilValue));
  R_RegisterCFinalizerEx(result, processx__finalizer, 1);
  handle->cleanup = cleanup;

  UNPROTECT(1);
  return result;
}

static void processx__child_add(pid_t pid, SEXP status) {
  processx__child_list_t *child = malloc(sizeof(processx__child_list_t));
  child->pid = pid;
  child->status = status;
  child->next = child_list;
  child_list = child;
}

static void processx__child_remove(pid_t pid) {
  processx__child_list_t *ptr = child_list, *prev = 0;
  while (ptr) {
    if (ptr->pid == pid) {
      if (prev) {
	prev->next = ptr->next;
	free(ptr);
      } else {
	child_list = 0;
      }
      return;
    }
    prev = ptr;
    ptr = ptr->next;
  }
}

static processx__child_list_t *processx__child_find(pid_t pid) {
  processx__child_list_t *ptr = child_list;
  while (ptr) {
    if (ptr->pid == pid) return ptr;
    ptr = ptr->next;
  }
  return 0;
}

void processx__sigchld_callback(int sig, siginfo_t *info, void *ctx) {
  if (sig != SIGCHLD) return;
  pid_t pid = info->si_pid;
  processx__child_list_t *child = processx__child_find(pid);

  if (child) {
    /* We deliberately do not call the finalizer here, because that
       moves the exit code and pid to R, and we might have just checked
       that these are not in R, before calling C. So finalizing here
       would be a race condition.

       OTOH, we need to check if the handle is null, because a finalizer
       might actually run before the SIGCHLD handler. Or the finalizer
       might even trigger the SIGCHLD handler...
    */
    int wp, wstat;
    processx_handle_t *handle = R_ExternalPtrAddr(child->status);

    /* This might not be necessary, if the handle was finalized,
       but it does not hurt... */
    do {
      wp = waitpid(pid, &wstat, 0);
    } while (wp == -1 && errno == EINTR);

    /* If handle is NULL, then the exit status was collected already */
    if (handle) processx__collect_exit_status(child->status, wstat);

    processx__child_remove(pid);

    /* If no more children, then we do not need a SIGCHLD handler */
    if (!child_list) processx__remove_sigchld();

    /* If there is an active wait() with a timeout, then stop it */
    if (handle->waitpipe[1] >= 0) {
      close(handle->waitpipe[1]);
      handle->waitpipe[1] = -1;
    }
  }
}

/* TODO: use oldact */

static void processx__setup_sigchld() {
  struct sigaction action;
  action.sa_sigaction = processx__sigchld_callback;
  action.sa_flags = SA_SIGINFO | SA_RESTART | SA_NOCLDSTOP;
  sigaction(SIGCHLD, &action, /* oldact= */ NULL);
}

static void processx__remove_sigchld() {
  struct sigaction action;
  action.sa_handler = SIG_DFL;
  sigaction(SIGCHLD, &action, /* oldact= */ NULL);
}

static void processx__block_sigchld() {
  sigset_t blockMask;
  sigemptyset(&blockMask);
  sigaddset(&blockMask, SIGCHLD);
  if (sigprocmask(SIG_BLOCK, &blockMask, NULL) == -1) {
    error("processx error setting up signal handlers");
  }
}

static void processx__unblock_sigchld() {
  sigset_t unblockMask;
  sigemptyset(&unblockMask);
  sigaddset(&unblockMask, SIGCHLD);
  if (sigprocmask(SIG_UNBLOCK, &unblockMask, NULL) == -1) {
    error("processx error setting up signal handlers");
  }
}

void processx__make_socketpair(int pipe[2]) {
#if defined(__linux__)
  static int no_cloexec;
  if (no_cloexec)  goto skip;

  if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, pipe) == 0)
    return;

  /* Retry on EINVAL, it means SOCK_CLOEXEC is not supported.
   * Anything else is a genuine error.
   */
  if (errno != EINVAL) {
    error("processx socketpair: %s", strerror(errno));
  }

  no_cloexec = 1;

skip:
#endif

  if (socketpair(AF_UNIX, SOCK_STREAM, 0, pipe)) {
    error("processx socketpair: %s", strerror(errno));
  }

  processx__cloexec_fcntl(pipe[0], 1);
  processx__cloexec_fcntl(pipe[1], 1);
}

void processx__con_destroy(Rconnection con) {
  if (con->status >= 0) {
    close(con->status);
    con->status = -1;
    con->isopen = 0;
  }
}

size_t processx__con_read(void *target, size_t sz, size_t ni,
			  Rconnection con) {
  int num;
  int fd = con->status;
  int whichfd;
  processx_handle_t *handle = con->private;

  if (fd < 0) error("Connection was already closed");
  if (sz != 1) error("Can only read bytes from processx connections");

  if (fd == handle->fd1) whichfd = 1; else whichfd = 2;

  /* Already got EOF? */
  if (con->EOF_signalled) return 0;

  num = read(fd, target, ni);

  con->incomplete = 1;

  if (num < 0 && errno == EAGAIN) {
    num = 0;			/* cannot return negative number */

  } else if (num < 0) {
    error("Cannot read from processx pipe");

  } else if (num == 0) {
    con->incomplete = 0;
    con->EOF_signalled = 1;
    /* If the last line does not have a trailing '\n', then
       we add one manually, because otherwise readLines() will
       never read this line. */
    if (handle->tails[whichfd] != '\n') {
      ((char*)target)[0] = '\n';
      num = 1;
    }

  } else {
    /* Make note of the last character, to know if the last line
       was incomplete or not. */
    handle->tails[whichfd] = ((char*)target)[num - 1];
  }

  return (size_t) num;
}

int processx__con_fgetc(Rconnection con) {
  int x = 0;
#ifdef WORDS_BIGENDIAN
  return processx__con_read(&x, 1, 1, con) ? BSWAP_32(x) : -1;
#else
  return processx__con_read(&x, 1, 1, con) ? x : -1;
#endif
}

void processx__create_connection(processx_handle_t *handle,
				 int fd, const char *membername,
				 SEXP private) {

  Rconnection con;
  SEXP res =
    PROTECT(R_new_custom_connection("processx", "r", "textConnection", &con));

  int whichfd;
  if (fd == handle->fd1) whichfd = 1; else whichfd = 2;
  handle->tails[whichfd] = '\n';

  con->incomplete = 1;
  con->EOF_signalled = 0;
  con->private = handle;
  con->status = fd;		/* slight abuse */
  con->canseek = 0;
  con->canwrite = 0;
  con->canread = 1;
  con->isopen = 1;
  con->blocking = 0;
  con->text = 1;
  con->UTF8out = 1;
  con->destroy = &processx__con_destroy;
  con->read = &processx__con_read;
  con->fgetc = &processx__con_fgetc;
  con->fgetc_internal = &processx__con_fgetc;

  defineVar(install(membername), res, private);
  UNPROTECT(1);
}

void processx__create_connections(processx_handle_t *handle, SEXP private) {

  if (handle->fd1 >= 0) {
    processx__create_connection(handle, handle->fd1, "stdout_pipe", private);
  }

  if (handle->fd2 >= 0) {
    processx__create_connection(handle, handle->fd2, "stderr_pipe", private);
  }
}

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP detached, SEXP windows_verbatim_args,
		   SEXP windows_hide_window, SEXP private, SEXP cleanup) {

  char *ccommand = processx__tmp_string(command, 0);
  char **cargs = processx__tmp_character(args);
  int ccleanup = INTEGER(cleanup)[0];
  const char *cstdout = isNull(stdout) ? 0 : CHAR(STRING_ELT(stdout, 0));
  const char *cstderr = isNull(stderr) ? 0 : CHAR(STRING_ELT(stderr, 0));
  processx_options_t options = { 0 };

  pid_t pid;
  int err, exec_errorno = 0, status;
  ssize_t r;
  int signal_pipe[2] = { -1, -1 };
  int pipes[3][2] = { { -1, -1 }, { -1, -1 }, { -1, -1 } };

  processx_handle_t *handle = NULL;
  SEXP result;

  options.detached = LOGICAL(detached)[0];

  if (pipe(signal_pipe)) { goto cleanup; }
  processx__cloexec_fcntl(signal_pipe[0], 1);
  processx__cloexec_fcntl(signal_pipe[1], 1);

  processx__setup_sigchld();

  result = PROTECT(processx__make_handle(private, ccleanup));
  handle = R_ExternalPtrAddr(result);

  /* Create pipes, if requested. TODO: stdin */
  if (cstdout && !strcmp(cstdout, "|")) processx__make_socketpair(pipes[1]);
  if (cstderr && !strcmp(cstderr, "|")) processx__make_socketpair(pipes[2]);

  processx__block_sigchld();

  pid = fork();

  if (pid == -1) {		/* ERROR */
    err = -errno;
    close(signal_pipe[0]);
    close(signal_pipe[1]);
    processx__unblock_sigchld();
    goto cleanup;
  }

  /* CHILD */
  if (pid == 0) {
    processx__child_init(handle, pipes, ccommand, cargs, signal_pipe[1],
			 cstdout, cstderr, &options);
    goto cleanup;
  }

  /* We need to know the processx children */
  processx__child_add(pid, result);

  /* SIGCHLD can arrive now */
  processx__unblock_sigchld();

  close(signal_pipe[1]);

  do {
    r = read(signal_pipe[0], &exec_errorno, sizeof(exec_errorno));
  } while (r == -1 && errno == EINTR);

  if (r == 0) {
    ; /* okay, EOF */
  } else if (r == sizeof(exec_errorno)) {
    do {
      err = waitpid(pid, &status, 0); /* okay, read errorno */
    } while (err == -1 && errno == EINTR);

  } else if (r == -1 && errno == EPIPE) {
    do {
      err = waitpid(pid, &status, 0); /* okay, got EPIPE */
    } while (err == -1 && errno == EINTR);

  } else {
    goto cleanup;
  }

  close(signal_pipe[0]);

  /* Set fds for standard I/O */
  /* TODO: implement stdin */
  handle->fd0 = handle->fd1 = handle->fd2 = -1;
  if (pipes[1][0] >= 0) {
    handle->fd1 = pipes[1][0];
    processx__nonblock_fcntl(handle->fd1, 1);
  }
  if (pipes[2][0] >= 0) {
    handle->fd2 = pipes[2][0];
    processx__nonblock_fcntl(handle->fd2, 1);
  }

  /* Closed unused ends of pipes */
  if (pipes[1][1] >= 0) close(pipes[1][1]);
  if (pipes[2][1] >= 0) close(pipes[2][1]);

  /* Create proper connections */
  processx__create_connections(handle, private);

  if (exec_errorno == 0) {
    handle->pid = pid;
    UNPROTECT(1);		/* result */
    return result;
  }

 cleanup:
  error("processx error");
}

/* Process status (and related functions).

   The main complication here, is that checking the status of the process
   might mean that we need to collect its exit status.

   * `process_wait`:
     1. If we already have its exit status, return immediately.
     2. Otherwise, do a blocking `waitpid()`.
     3. When it's done, collect the exit status.

   * `process_is_alive`:
     1. If we already have its exit status, then return `FALSE`.
     2. Otherwise, do a non-blocking `waitpid()`.
     3. If the `waitpid()` says that it is running, then return `TRUE`.
     4. Otherwise collect its exit status, and return `FALSE`.

   * `process_get_exit_status`:
     1. If we already have the exit status, then return that.
     2. Otherwise do a non-blocking `waitpid()`.
     3. If the process just finished, then collect the exit status, and
        also return it.
     4. Otherwise return `NULL`, the process is still running.

   * `process_signal`:
     1. If we already have its exit status, return with `FALSE`.
     2. Otherwise just try to deliver the signal. If successful, return
        `TRUE`, otherwise return `FALSE`.

     We might as well call `waitpid()` as well, but `process_signal` is
     able to deliver arbitrary signals, so the process might not have
     finished.

   * `process_kill`:
     1. Check if we have the exit status. If yes, then the process
        has already finished. and we return `FALSE`. We don't error,
        because then there would be no way to deliver a signal.
        (Simply doing `if (p$is_alive()) p$kill()` does not work, because
        it is a race condition.
     2. If there is no exit status, the process might be running (or might
        be a zombie).
     3. We call a non-blocking `waitpid()` on the process and potentially
        collect the exit status. If the process has exited, then we return
        TRUE. This step is to avoid the potential grace period, if the
        process is in a zombie state.
     4. If the process is still running, we call `kill(SIGKILL)`.
     5. We do a blocking `waitpid()` to collect the exit status.
     6. If the process was indeed killed by us, we return `TRUE`.
     7. Otherwise we return `FALSE`.

    The return value of `process_kill()` is `TRUE` if the process was
    indeed killed by the signal. It is `FALSE` otherwise, i.e. if the
    process finished.

    We currently ignore the grace argument, as there is no way to
    implement it on Unix. It will be implemented later using a SIGCHLD
    handler.

   * Finalizers (`processx__finalizer`):

     Finalizers are called on the handle only, so we do not know if the
     process has already finished or not.

     1. Call a non-blocking `waitpid()` to see if it is still running.
     2. If just finished, then collect exit status (=free memory).
     3. If it has finished before, then still try to free memory, just in
        case the exit status was read out by another package.
     4. If it is running, then kill it with SIGKILL, then call a blocking
        `waitpid()` to clean up the zombie process. Then free all memory.

     The finalizer is implemented in C, because we might need to use it
     from the process startup code (which is C).
*/

void processx__collect_exit_status(SEXP status, int wstat) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);

  /* This must be called from a function that blocks SIGCHLD.
     So we are not blocking it here. */

  if (!handle) {
    error("Invalid handle, already finalized");
  }

  if (handle->collected) { return; }

  /* We assume that errors were handled before */
  if (WIFEXITED(wstat)) {
    handle->exitcode = WEXITSTATUS(wstat);
  } else {
    handle->exitcode = - WTERMSIG(wstat);
  }

  handle->collected = 1;
}

SEXP processx__wait(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  pid_t pid;
  int wstat, wp;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  /* If we already have the status, then return now. */
  if (handle->collected) goto cleanup;

  /* Otherwise do a blocking waitpid */
  pid = handle->pid;
  do {
    wp = waitpid(pid, &wstat, 0);
  } while (wp == -1 && errno == EINTR);

  /* Error? */
  if (wp == -1) {
    processx__unblock_sigchld();
    error("processx_wait: %s", strerror(errno));
  }

  /* Collect exit status */
  processx__collect_exit_status(status, wstat);

 cleanup:
  processx__unblock_sigchld();
  return ScalarLogical(1);
}

SEXP processx__wait_timeout(SEXP status, SEXP timeout) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  int ctimeout = INTEGER(timeout)[0];
  struct pollfd fd;
  int ret;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  /* Make sure this is active, in case another package replaced it... */
  processx__setup_sigchld();

  /* Setup the self-pipe that we can poll */
  if (pipe(handle->waitpipe)) {
    processx__unblock_sigchld();
    error("processx error: %s", strerror(errno));
  }
  processx__nonblock_fcntl(handle->waitpipe[0], 1);
  processx__nonblock_fcntl(handle->waitpipe[1], 1);

  /* Poll on the pipe, need to unblock sigchld before */
  fd.fd = handle->waitpipe[0];
  fd.events = POLLIN;
  fd.revents = 0;

  processx__unblock_sigchld();

  do {
    ret = poll(&fd, 1, ctimeout);
  } while (ret == -1 && errno == EINTR);

  if (ret == -1) {
    error("processx wait with timeout error: %s", strerror(errno));
  }

  close(handle->waitpipe[0]);
  handle->waitpipe[0] = -1;

  return ScalarLogical(ret != 0);
}

SEXP processx_wait(SEXP status, SEXP timeout) {
  if (INTEGER(timeout)[0] < 0) {
    return processx__wait(status);

  } else {
    return processx__wait_timeout(status, timeout);
  }
}

SEXP processx_is_alive(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  pid_t pid;
  int wstat, wp;
  int ret = 0;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  if (handle->collected) goto cleanup;

  /* Otherwise a non-blocking waitpid to collect zombies */
  pid = handle->pid;
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) {
    processx__unblock_sigchld();
    error("processx_is_alive: %s", strerror(errno));
  }

  /* If running, return TRUE, otherwise collect exit status, return FALSE */
  if (wp == 0) {
    ret = 1;
  } else {
    processx__collect_exit_status(status, wstat);
  }

 cleanup:
  processx__unblock_sigchld();
  return ScalarLogical(ret);
}

SEXP processx_get_exit_status(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  pid_t pid;
  int wstat, wp;
  SEXP result;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  /* If we already have the status, then just return */
  if (handle->collected) {
    result = PROTECT(ScalarInteger(handle->exitcode));
    goto cleanup;
  }

  /* Otherwise do a non-blocking waitpid to collect zombies */
  pid = handle->pid;
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) {
    processx__unblock_sigchld();
    error("processx_get_exit_status: %s", strerror(errno));
  }

  /* If running, do nothing otherwise collect */
  if (wp == 0) {
    result = PROTECT(R_NilValue);
  } else {
    processx__collect_exit_status(status, wstat);
    result = PROTECT(ScalarInteger(handle->exitcode));
  }

 cleanup:
  processx__unblock_sigchld();
  UNPROTECT(1);
  return result;
}

SEXP processx_signal(SEXP status, SEXP signal) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  pid_t pid;
  int wstat, wp, ret, result;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  /* If we already have the status, then return `FALSE` */
  if (handle->collected) {
    result = 0;
    goto cleanup;
  }

  /* Otherwise try to send signal */
  pid = handle->pid;
  ret = kill(pid, INTEGER(signal)[0]);

  if (ret == 0) {
    result = 1;
  } else if (ret == -1 && errno == ESRCH) {
    result = 0;
  } else {
    processx__unblock_sigchld();
    error("processx_signal: %s", strerror(errno));
    return R_NilValue;
  }

  /* Dead now, collect status */
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  if (wp == -1) {
    processx__unblock_sigchld();
    error("processx_get_exit_status: %s", strerror(errno));
  }

 cleanup:
  processx__unblock_sigchld();
  return ScalarLogical(result);
}

SEXP processx_kill(SEXP status, SEXP grace) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  pid_t pid;
  int wstat, wp, result = 0;

  processx__block_sigchld();

  if (!handle) {
    processx__unblock_sigchld();
    error("Internal processx error, handle already removed");
  }

  /* Check if we have an exit status, it yes, just return (FALSE) */
  if (handle->collected) { goto cleanup; }

  /* Do a non-blocking waitpid to collect zombies */
  pid = handle->pid;
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) {
    processx__unblock_sigchld();
    error("processx_kill: %s", strerror(errno));
  }

  /* If the process is not running, return (FALSE) */
  if (wp != 0) { goto cleanup; }

  /* It is still running, so a SIGKILL */
  int ret = kill(pid, SIGKILL);
  if (ret == -1 && errno == ESRCH) { goto cleanup; }
  if (ret == -1) {
    processx__unblock_sigchld();
    error("process_kill: %s", strerror(errno));
  }

  /* Do a waitpid to collect the status and reap the zombie */
  do {
    wp = waitpid(pid, &wstat, 0);
  } while (wp == -1 && errno == EINTR);

  /* Collect exit status, and check if it was killed by a SIGKILL
     If yes, this was most probably us (although we cannot be sure in
     general... */
  processx__collect_exit_status(status, wstat);
  result = handle->exitcode == - SIGKILL;

 cleanup:
  processx__unblock_sigchld();
  return ScalarLogical(result);
}

SEXP processx_get_pid(SEXP status) {
  processx_handle_t *handle = R_ExternalPtrAddr(status);

  if (!handle) { error("Internal processx error, handle already removed"); }

  return ScalarInteger(handle->pid);
}

static int processx__poll_decode(short code) {
  if (code & POLLNVAL) return PXCLOSED;
  if (code & POLLIN || code & POLLHUP) return PXREADY;
  return 0;
}

SEXP processx_poll_io(SEXP status, SEXP ms, SEXP stdout_pipe, SEXP stderr_pipe) {
  int cms = INTEGER(ms)[0];
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  struct pollfd fds[2];
  int idx = 0, num = 0, ret;
  SEXP result;
  int ptr1 = -1, ptr2 = -1;

  if (!handle) { error("Internal processx error, handle already removed"); }

  if (handle->fd1 >= 0) {
    fds[idx].fd = handle->fd1;
    fds[idx].events = POLLIN;
    fds[idx].revents = 0;
    ptr1 = idx;
    idx++;
  }
  if (handle->fd2 >= 0) {
    fds[idx].fd = handle->fd2;
    fds[idx].events = POLLIN;
    fds[idx].revents = 0;
    ptr2 = idx;
  }

  result = PROTECT(allocVector(INTSXP, 2));
  if (isNull(stdout_pipe)) {
    INTEGER(result)[0] = PXNOPIPE;
  } else if (handle->fd1 < 0) {
    INTEGER(result)[0] = PXCLOSED;
  } else {
    num++;
    INTEGER(result)[0] = PXSILENT;
  }
  if (isNull(stderr_pipe)) {
    INTEGER(result)[1] = PXNOPIPE;
  } else if (handle->fd2 < 0) {
    INTEGER(result)[1] = PXCLOSED;
  } else {
    num++;
    INTEGER(result)[1] = PXSILENT;
  }

  /* Nothing to poll? */
  if (num == 0) {
    UNPROTECT(1);
    return result;
  }

  do {
    ret = poll(fds, num, cms);
  } while (ret == -1 && errno == EINTR);

  if (ret == -1) {
    error("Processx poll error: %s", strerror(errno));

  } else if (ret == 0) {
    if (ptr1 >= 0) INTEGER(result)[0] = PXTIMEOUT;
    if (ptr2 >= 0) INTEGER(result)[1] = PXTIMEOUT;

  } else {
    if (ptr1 >= 0 && fds[ptr1].revents) {
      INTEGER(result)[0] = processx__poll_decode(fds[ptr1].revents);
    }
    if (ptr2 >= 0 && fds[ptr2].revents) {
      INTEGER(result)[1] = processx__poll_decode(fds[ptr2].revents);
    }
  }

  UNPROTECT(1);
  return result;
}

SEXP processx__process_exists(SEXP pid) {
  pid_t cpid = INTEGER(pid)[0];
  int res = kill(cpid, 0);
  if (res == 0) {
    return ScalarLogical(1);
  } else if (errno == ESRCH) {
    return ScalarLogical(0);
  } else {
    error("kill syscall error: %s", strerror(errno));
    return R_NilValue;
  }
}

#endif
