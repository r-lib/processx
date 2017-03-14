
void processx_win_dummy() { }

#ifdef WIN32

#include <Rinternals.h>
#include <windows.h>

#include "utils.h"

SEXP processx_exec(SEXP command, SEXP args, SEXP stdout, SEXP stderr,
		   SEXP detached) {

  return R_NilValue;
}

#endif

