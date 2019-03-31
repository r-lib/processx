
#include <R.h>
#include <Rinternals.h>

#define SAFECALL_REGISTRATION_RECORD \
  { "safecall", (DL_FUNC) safecall, 3 }
#define r_on_exit(a,b) r_on_exit_reg(a,b)

SEXP safecall(SEXP addr, SEXP numpar, SEXP args);
void r_on_exit_reg(void (*func)(void*), void *data);
