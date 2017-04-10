
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
