
void processx_unix_dummy() { }

#ifndef _WIN32

#include <Rinternals.h>

#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <signal.h>

#include "utils.h"

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

static void processx__child_init(char *command, char **args, int error_fd,
				 const char *stdout, const char *stderr,
				 processx_options_t *options) {

  int err;
  int fd0, fd1, fd2, use_fd0, use_fd1, use_fd2,
    close_fd0, close_fd1, close_fd2;

  if (options->detached) setsid();

  /* Handle stdin, stdout, stderr
     For now, we just redirect them to the supplied files (if not NULL).  */

  close_fd0 = use_fd0 = open("/dev/null", O_RDONLY);
  if (use_fd0 == -1) raise(SIGKILL);

  if (stdout) {
    close_fd1 = use_fd1 = open(stdout, O_CREAT | O_TRUNC| O_RDWR, 0644);
  } else {
    close_fd1 = use_fd1 = open("/dev/null", O_RDWR);
  }
  if (use_fd1 == -1) raise(SIGKILL);

  if (stderr) {
    close_fd2 = use_fd2 = open(stderr, O_CREAT | O_TRUNC | O_RDWR, 0644);
  } else {
    close_fd2 = use_fd2 = open("/dev/null", O_RDWR);
  }
  if (use_fd2 == -1) raise(SIGKILL);

  fd0 = dup2(use_fd0, 0);
  if (fd0 == -1) raise(SIGKILL);
  fd1 = dup2(use_fd1, 1);
  if (fd1 == -1) raise(SIGKILL);
  fd2 = dup2(use_fd2, 2);
  if (fd2 == -1) raise(SIGKILL);

  processx__nonblock_fcntl(fd0, 0);
  processx__nonblock_fcntl(fd1, 0);

  execvp(command, args);
  err = -errno;
  write(error_fd, &err, sizeof(int));
  raise(SIGKILL);
}

void processx__finalizer(SEXP ptr) {
  processx_handle_t *handle = (processx_handle_t*) R_ExternalPtrAddr(ptr);
  pid_t pid;
  int wp, wstat;

  /* Already freed? */
  if (!handle) return;

  /* Do a non-blocking waitpid() to see if it is running */
  pid = handle->pid;
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* If it is running, we need to kill it */
  if (wp == 0) {
    kill(pid, SIGKILL);
    do {
      wp = waitpid(pid, &wstat, 0);
    } while (wp == -1 && errno == EINTR);
  }

  /* It is dead now, clean up */
  processx__handle_destroy(handle);
  R_ClearExternalPtr(ptr);
}

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP detached, SEXP windows_verbatim_args) {

  char *ccommand = processx__tmp_string(command, 0);
  char **cargs = processx__tmp_character(args);
  const char *cstdout = isNull(stdout) ? 0 : CHAR(STRING_ELT(stdout, 0));
  const char *cstderr = isNull(stderr) ? 0 : CHAR(STRING_ELT(stderr, 0));
  processx_options_t options = { 0 };

  pid_t pid;
  int err, exec_errorno = 0, status;
  ssize_t r;
  int signal_pipe[2] = { -1, -1 };

  processx_handle_t *handle = NULL;
  SEXP result;

  options.detached = LOGICAL(detached)[0];

  if (pipe(signal_pipe)) { goto cleanup; }
  processx__cloexec_fcntl(signal_pipe[0], 1);
  processx__cloexec_fcntl(signal_pipe[1], 1);

  /* TODO: put the new child into the child list */

  /* TODO: make sure signal handler is set up */

  handle = (processx_handle_t*) malloc(sizeof(processx_handle_t));
  if (!handle) { goto cleanup; }
  memset(handle, 0, sizeof(processx_handle_t));
  result = PROTECT(allocVector(VECSXP, 3));
  SET_VECTOR_ELT(result, 0, R_NilValue);
  SET_VECTOR_ELT(result, 1, allocVector(INTSXP, 1));
  SET_VECTOR_ELT(result, 2,
		 R_MakeExternalPtr(handle, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(VECTOR_ELT(result, 2), processx__finalizer, 1);

  pid = fork();

  if (pid == -1) {		/* ERROR */
    err = -errno;
    close(signal_pipe[0]);
    close(signal_pipe[1]);
    goto cleanup;
  }

  /* CHILD */
  if (pid == 0) {
    processx__child_init(ccommand, cargs, signal_pipe[1], cstdout,
			 cstderr, &options);
    goto cleanup;
  }

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

  if (exec_errorno == 0) {
    INTEGER(VECTOR_ELT(result, 1))[0] = handle->pid = pid;
    UNPROTECT(1);		/* result */
    return result;
  }

 cleanup:
  error("processx error");
}

SEXP processx__collect_exit_status(SEXP status, int wstat) {
  SEXP result = duplicate(status);

  SET_VECTOR_ELT(result, 0, allocVector(INTSXP, 1));

  /* We assume that errors were handled before */
  if (WIFEXITED(wstat)) {
    INTEGER(VECTOR_ELT(result, 0))[0] = WEXITSTATUS(wstat);
  } else {
    INTEGER(VECTOR_ELT(result, 0))[0] = - WTERMSIG(wstat);
  }

  return result;
}

SEXP processx_wait(SEXP status) {
  pid_t pid;
  int wstat, wp;

  /* If we already have the status, then return now. */
  if (!isNull(VECTOR_ELT(status, 0))) { return status; }

  /* Otherwise do a blocking waitpid */
  pid = INTEGER(VECTOR_ELT(status, 1))[0];
  do {
    wp = waitpid(pid, &wstat, 0);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) { error("processx_wait: %s", strerror(errno)); }

  /* Collect exit status, and return it */
  return processx__collect_exit_status(status, wstat);
}

SEXP processx_is_alive(SEXP status) {
  pid_t pid;
  int wstat, wp;

  /* If we already have the status, return now. */
  if (!isNull(VECTOR_ELT(status, 0))) { return status; }

  /* Otherwise a non-blocking waitpid to collect zombies */
  pid = INTEGER(VECTOR_ELT(status, 1))[0];
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) { error("processx_is_alive: %s", strerror(errno)); }

  /* If running, just return, otherwise collect exit status */
  if (wp == 0) {
    return status;
  } else {
    return processx__collect_exit_status(status, wstat);
  }
}

SEXP processx_get_exit_status(SEXP status, SEXP signal) {
  pid_t pid;
  int wp, wstat;

  /* If we already have the status, then just return */
  if (!isNull(VECTOR_ELT(status, 0))) { return status; }

  /* Otherwise do a non-blocking waitpid to collect zombies */
  pid = INTEGER(VECTOR_ELT(status, 1))[0];
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) { error("processx_get_exit_status: %s", strerror(errno)); }

  /* If running, do nothing otherwise collect */
  if (wp == 0) {
    return status;
  } else {
    return processx__collect_exit_status(status, wstat);
  }
}

SEXP processx_signal(SEXP status, SEXP signal) {
  pid_t pid;
  int ret;

  /* If we already have the status, then return `FALSE` */
  if (!isNull(VECTOR_ELT(status, 0))) { return ScalarLogical(0); }

  /* Otherwise try to kill*/
  pid = INTEGER(VECTOR_ELT(status, 1))[0];
  ret = kill(pid, INTEGER(signal)[0]);

  if (ret == 0) {
    return ScalarLogical(1);
  } else if (ret == -1 && errno == ESRCH) {
    return ScalarLogical(0);
  } else {
    error("processx_signal: %s", strerror(errno));
    return R_NilValue;
  }
}

SEXP processx_kill(SEXP status, SEXP grace) {
  SEXP result = PROTECT(allocVector(VECSXP, 2));
  pid_t pid;
  int wp, wstat;

  SET_VECTOR_ELT(result, 0, duplicate(status));
  SET_VECTOR_ELT(result, 1, allocVector(LGLSXP, 1));

  /* Check if we have an exit status, it yes, just return (FALSE) */
  if (!isNull(VECTOR_ELT(status, 0))) { UNPROTECT(1); return result; }

  /* Do a non-blocking waitpid to collect zombies */
  pid = INTEGER(VECTOR_ELT(status, 1))[0];
  do {
    wp = waitpid(pid, &wstat, WNOHANG);
  } while (wp == -1 && errno == EINTR);

  /* Some other error? */
  if (wp == -1) { error("processx_kill: %s", strerror(errno)); }

  /* If the process is not running, return (FALSE) */
  if (wp != 0) { UNPROTECT(1); return result; }

  /* It is still running, so a SIGKILL */
  int ret = kill(pid, SIGTERM);
  if (ret == -1 && errno == ESRCH) { UNPROTECT(1); return result; }
  if (ret == -1) { error("process_kill: %s", strerror(errno)); }

  /* Do a waitpid to collect the status and reap the zombie */
  do {
    wp = waitpid(pid, &wstat, 0);
  } while (wp == -1 && errno == EINTR);

  /* Collect exit status, and check if it was killed by a SIGKILL
     If yes, this was most probably us (although we cannot be sure in
     general... */
  SET_VECTOR_ELT(result, 0, processx__collect_exit_status(status, wstat));
  LOGICAL(VECTOR_ELT(result, 1))[0] =
    INTEGER(VECTOR_ELT(VECTOR_ELT(result, 0), 0))[0] == SIGKILL;

  UNPROTECT(1);
  return result;
}

#endif
