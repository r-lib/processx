
#include <R_ext/Rdynload.h>

#include "processx.h"

#ifndef _WIN32
void R_init_processx_unix();
#endif

SEXP processx__killem_all();

static const R_CallMethodDef callMethods[]  = {
  { "processx_exec",            (DL_FUNC) &processx_exec,            8 },
  { "processx_wait",            (DL_FUNC) &processx_wait,            2 },
  { "processx_is_alive",        (DL_FUNC) &processx_is_alive,        1 },
  { "processx_get_exit_status", (DL_FUNC) &processx_get_exit_status, 1 },
  { "processx_signal",          (DL_FUNC) &processx_signal,          2 },
  { "processx_kill",            (DL_FUNC) &processx_kill,            2 },
  { "processx_get_pid",         (DL_FUNC) &processx_get_pid,         1 },
  { "processx_poll_io",         (DL_FUNC) &processx_poll_io,         4 },
  { "processx_poll",            (DL_FUNC) &processx_poll,            4 },
  { "processx__process_exists", (DL_FUNC) &processx__process_exists, 1 },
  { "processx__killem_all",     (DL_FUNC) &processx__killem_all,     0 },
  { NULL, NULL, 0 }
};

void R_init_processx(DllInfo *dll) {
  R_registerRoutines(dll, NULL, callMethods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
#ifndef _WIN32
  R_init_processx_unix();
#endif
}
