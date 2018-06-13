
#include "processx.h"

#include <R_ext/Rdynload.h>
#include <R.h>

void R_init_processx_win();
void R_init_processx_unix();
SEXP processx__killem_all();
SEXP run_testthat_tests();

static const R_CallMethodDef callMethods[]  = {
  { "processx_exec",               (DL_FUNC) &processx_exec,              14 },
  { "processx_wait",               (DL_FUNC) &processx_wait,               2 },
  { "processx_is_alive",           (DL_FUNC) &processx_is_alive,           1 },
  { "processx_get_exit_status",    (DL_FUNC) &processx_get_exit_status,    1 },
  { "processx_signal",             (DL_FUNC) &processx_signal,             2 },
  { "processx_interrupt",          (DL_FUNC) &processx_interrupt,          1 },
  { "processx_kill",               (DL_FUNC) &processx_kill,               2 },
  { "processx_get_pid",            (DL_FUNC) &processx_get_pid,            1 },
  { "processx_create_time",        (DL_FUNC) &processx_create_time,        1 },
  { "processx_poll",               (DL_FUNC) &processx_poll,               3 },
  { "processx__process_exists",    (DL_FUNC) &processx__process_exists,    1 },
  { "processx__killem_all",        (DL_FUNC) &processx__killem_all,        0 },
  { "processx_is_named_pipe_open", (DL_FUNC) &processx_is_named_pipe_open, 1 },
  { "processx_close_named_pipe",   (DL_FUNC) &processx_close_named_pipe,   1 },
  { "processx_create_named_pipe",  (DL_FUNC) &processx_create_named_pipe,  2 },
  { "processx_write_named_pipe",   (DL_FUNC) &processx_write_named_pipe,   2 },
  { "processx__proc_start_time",   (DL_FUNC) &processx__proc_start_time,   1 },

  { "processx_connection_create",     (DL_FUNC) &processx_connection_create,     2 },
  { "processx_connection_read_chars", (DL_FUNC) &processx_connection_read_chars, 2 },
  { "processx_connection_read_lines", (DL_FUNC) &processx_connection_read_lines, 2 },
  { "processx_connection_write_bytes",(DL_FUNC) &processx_connection_write_bytes,2 },
  { "processx_connection_is_eof",     (DL_FUNC) &processx_connection_is_eof,     1 },
  { "processx_connection_close",      (DL_FUNC) &processx_connection_close,      1 },
  { "processx_connection_poll",       (DL_FUNC) &processx_connection_poll,       2 },

  { "processx_connection_create_pipepair",
    (DL_FUNC) processx_connection_create_pipepair, 1 },
  { "processx_connection_create_fd",  (DL_FUNC) &processx_connection_create_fd,  3 },
  { "processx_connection_create_file",
    (DL_FUNC) &processx_connection_create_file,    3 },
  { "processx_connection_set_stdout", (DL_FUNC) &processx_connection_set_stdout,  2 },
  { "processx_connection_set_stderr", (DL_FUNC) &processx_connection_set_stderr,  2 },
  { "processx_connection_get_fileno", (DL_FUNC) &processx_connection_get_fileno,  1 },
  { "processx_connection_disable_inheritance",
    (DL_FUNC) &processx_connection_disable_inheritance, 0 },

  { "processx_disable_crash_dialog",  (DL_FUNC) &processx_disable_crash_dialog,   0 },

  { NULL, NULL, 0 }
};

void R_init_processx(DllInfo *dll) {
  R_registerRoutines(dll, NULL, callMethods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
#ifdef _WIN32
  R_init_processx_win();
#else
  R_init_processx_unix();
#endif
}
