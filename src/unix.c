
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

typedef struct {
  int detached;
} processx_options_t;

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

  close_fd1 = use_fd1 = open(stdout ? stdout : "/dev/null",
			     O_APPEND | O_RDWR, 0);
  if (use_fd1 == -1) raise(SIGKILL);

  close_fd2 = use_fd2 = open(stderr ? stderr : "/dev/null",
			     O_APPEND | O_RDWR, 0);
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

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP detached) {

  SEXP handle = R_NilValue;
  char *ccommand = processx__tmp_string(command, 0);
  char **cargs = processx__tmp_character(args);
  const char *cstdout = isNull(stdout) ? 0 : CHAR(STRING_ELT(stdout, 0));
  const char *cstderr = isNull(stderr) ? 0 : CHAR(STRING_ELT(stderr, 0));
  processx_options_t options = { 0 };

  pid_t pid;
  int err, exec_errorno = 0, status;
  ssize_t r;
  int signal_pipe[2] = { -1, -1 };

  options.detached = LOGICAL(detached)[0];

  if (pipe(signal_pipe)) { goto cleanup; }
  processx__cloexec_fcntl(signal_pipe[0], 1);
  processx__cloexec_fcntl(signal_pipe[1], 1);

  /* TODO: put the new child into the child list */

  /* TODO: make sure signal handler is set up */

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
    return ScalarInteger(pid);
    return handle;

  } else {
    error("Cannot start process");
  }

 cleanup:
  error("processx error");
}

SEXP processx_wait(SEXP pid, SEXP hang) {
  pid_t cpid = INTEGER(pid)[0];
  int chang = LOGICAL(hang)[0];
  SEXP result = PROTECT(allocVector(INTSXP, 3));
  int wstat, wp;

  INTEGER(result)[0] = 0;	/* JUST DIED */

  do {
    wp = waitpid(cpid, &wstat, chang ? 0 : WNOHANG);
  } while (pid == -1 && errno == EINTR);

  /* Some sort of error? */

  if (! chang && wp == 0) {
    /* Still running and we didn't want to wait */
    INTEGER(result)[0] = 1;	/* RUNNING */
    goto done;

  } else if (wp == -1 && errno == ECHILD) {
    /* No process to wait on, dead already? */
    INTEGER(result)[0] = 2;	/* ALREADY DEAD */
    goto done;

  } else if (wp == -1) {
    /* Other error */
    error("processx error: %s", strerror(errno));
  }

  /* Otherwise we successfully waited and continue to grab the status */

  if (WIFEXITED(wstat)) {
    INTEGER(result)[1] = WEXITSTATUS(wstat);
  } else {
    INTEGER(result)[2] = WTERMSIG(wstat);
  }

 done:
  UNPROTECT(1);
  return result;
}

#endif
