
#ifndef PROCESSX_UNIX_H
#define PROCESSX_UNIX_H

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

#include "../processx.h"

typedef struct processx_handle_s {
  int exitcode;
  int collected;	 /* Whether exit code was collected already */
  pid_t pid;
  int fd0;			/* writeable */
  int fd1;			/* readable */
  int fd2;			/* readable */
  char tails[3];
  int waitpipe[2];		/* use it for wait() with timeout */
  int cleanup;
} processx_handle_t;

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

void processx__sigchld_callback(int sig, siginfo_t *info, void *ctx);
void processx__setup_sigchld();
void processx__remove_sigchld();
void processx__block_sigchld();
void processx__unblock_sigchld();

void processx__finalizer(SEXP status);
SEXP processx__killem_all();

/* Child list and its functions */

typedef struct processx__child_list_s {
  pid_t pid;
  SEXP status;
  struct processx__child_list_s *next;
} processx__child_list_t;

int processx__child_add(pid_t pid, SEXP status);
void processx__child_remove(pid_t pid);
processx__child_list_t *processx__child_find(pid_t pid);
void processx__freelist_add(processx__child_list_t *ptr);
void processx__freelist_free();

void processx__collect_exit_status(SEXP status, int wstat);

int processx__nonblock_fcntl(int fd, int set);
int processx__cloexec_fcntl(int fd, int set);

/* Connections */

void processx__create_connections(processx_handle_t *handle, SEXP private);
void processx__con_destroy(Rconnection con);
size_t processx__con_read(void *target, size_t sz, size_t ni,
			  Rconnection con);
int processx__con_fgetc(Rconnection con);
void processx__create_connection(processx_handle_t *handle,
				 int fd, const char *membername,
				 SEXP private);

/* Control connections*/

void processx__create_control_read(processx_handle_t *handle,
				   int fd, const char *membername,
				   SEXP private);
void processx__create_control_write(processx_handle_t *handle,
				    int fd, const char *membername,
				    SEXP private);

/* Interruptible system calls */

int processx__interruptible_poll(struct pollfd fds[],
				 nfds_t nfds, int timeout);

#endif
