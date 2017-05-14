
#ifndef PROCESSX_H
#define PROCESSX_H

#include <Rinternals.h>

/* API from R */

SEXP processx_exec(SEXP command, SEXP args, SEXP std_out, SEXP std_err,
		   SEXP windows_verbatim_args,
		   SEXP windows_hide_window, SEXP private, SEXP cleanup);
SEXP processx_wait(SEXP status, SEXP timeout);
SEXP processx_is_alive(SEXP status);
SEXP processx_get_exit_status(SEXP status);
SEXP processx_signal(SEXP status, SEXP signal);
SEXP processx_kill(SEXP status, SEXP grace);
SEXP processx_get_pid(SEXP status);
SEXP processx_poll_io(SEXP status, SEXP ms, SEXP stdout_pipe,
		      SEXP stderr_pipe);

SEXP processx_poll(SEXP statuses, SEXP ms, SEXP outputs, SEXP errors);

SEXP processx__process_exists(SEXP pid);

/* Common declarations */

#include <Rinternals.h>

#include <R_ext/Connections.h>
#if ! defined(R_CONNECTIONS_VERSION) || R_CONNECTIONS_VERSION != 1
#error "Unsupported connections API version"
#endif

/* Interruption interval in ms */
#define PROCESSX_INTERRUPT_INTERVAL 200

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
  int windows_verbatim_args;
  int windows_hide;
} processx_options_t;

#endif
