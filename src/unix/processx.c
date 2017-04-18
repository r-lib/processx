
#ifndef _WIN32

#include "processx-unix.h"

/* Internals */

static void processx__child_init(processx_handle_t *handle, int pipes[3][2],
				 char *command, char **args, int error_fd,
				 const char *stdout, const char *stderr,
				 processx_options_t *options);
static void processx__finalizer(SEXP status);

static SEXP processx__make_handle(SEXP private, int cleanup);
static void processx__handle_destroy(processx_handle_t *handle);

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

void processx__write_int(int fd, int err) {
  int dummy = write(fd, &err, sizeof(int));
  (void) dummy;
}

static void processx__child_init(processx_handle_t* handle, int pipes[3][2],
				 char *command, char **args, int error_fd,
				 const char *stdout, const char *stderr,
				 processx_options_t *options) {

  int fd0, fd1, fd2, i;

  setsid();

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

  for (i = 3; i < sysconf(_SC_OPEN_MAX); i++) {
    if(i != error_fd) close(i);
  }

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

  /* Free child list nodes that are not needed any more. */
  processx__freelist_free();

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
      kill(-pid, SIGKILL);
      do {
	wp = waitpid(pid, &wstat, 0);
      } while (wp == -1 && errno == EINTR);
      processx__collect_exit_status(status, wstat);
    }
  }

  /* Copy over pid and exit status */
  private = R_ExternalPtrTag(status);
  defineVar(install("exited"), ScalarLogical(1), private);
  defineVar(install("pid"), ScalarInteger(pid), private);
  defineVar(install("exitcode"), ScalarInteger(handle->exitcode), private);

  /* Note: if no cleanup is requested, then we still have a sigchld
     handler, to read out the exit code via waitpid, but no handle
     any more. */

  /* Deallocate memory */
  R_ClearExternalPtr(status);
  processx__handle_destroy(handle);

 cleanup:
  processx__unblock_sigchld();
}

static SEXP processx__make_handle(SEXP private, int cleanup) {
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

static void processx__handle_destroy(processx_handle_t *handle) {
  if (!handle) return;
  free(handle);
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

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP windows_verbatim_args,
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
  if (processx__child_add(pid, result)) {
    err = -errno;
    close(signal_pipe[0]);
    close(signal_pipe[1]);
    processx__unblock_sigchld();
    goto cleanup;
  }

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
  processx__block_sigchld();

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
  close(handle->waitpipe[1]);
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
  int ret = kill(-pid, SIGKILL);
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
