
#ifndef R_PROCESSX_UTILS_H
#define R_PROCESSX_UTILS_H

#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#include <Rinternals.h>

#include <R_ext/Connections.h>
#if ! defined(R_CONNECTIONS_VERSION) || R_CONNECTIONS_VERSION != 1
#error "Unsupported connections API version"
#endif

#include <string.h>

/* Various OSes and OS versions return various poll codes when the
   child's end of the pipe is closed, so we cannot provide a more
   elaborate API. See e.g. http://www.greenend.org.uk/rjk/tech/poll.html
   In particular, (recent) macOS return both POLLIN and POLLHUP,
   Cygwin return POLLHUP, and most others return just POLLIN, so there
   is not way to distinguish. Essentially, if a read would not block,
   and the fd is still open, then we return with PXREADY.

   So for us, we just have:
*/

#define PXNOPIPE  1		/* we never captured this output */
#define PXREADY   2		/* one fd is ready, or got EOF */
#define PXTIMEOUT 3		/* no fd is ready before the timeout */
#define PXCLOSED  4		/* fd was already closed when started polling */
#define PXSILENT  5		/* still open, but no data or EOF for now. No timeout, either */
                                /* but there were events on other fds */

typedef struct {
  int detached;
  int windows_verbatim_args;
  int windows_hide;
} processx_options_t;

#ifdef WIN32
struct processx_handle_s;
typedef struct processx_pipe_handle_s {
  HANDLE pipe;
  OVERLAPPED overlapped;
  BYTE *buffer;
  DWORD buffer_size;
  BYTE *buffer_end;
  BOOLEAN read_pending;
  BOOLEAN EOF_signalled;
  char tail;
} processx_pipe_handle_t;

typedef struct processx_handle_s {
  int exitcode;
  int collected;	 /* Whether exit code was collected already */
  HANDLE hProcess;
  DWORD  dwProcessId;
  BYTE *child_stdio_buffer;
  HANDLE waitObject;
  processx_pipe_handle_t *pipes[3];
  int cleanup;
} processx_handle_t;

#else // Unix

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
#endif

void processx__handle_destroy(processx_handle_t *handle);

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

#endif
