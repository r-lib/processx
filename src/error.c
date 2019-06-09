
#include <Rinternals.h>

SEXP processx__stop(SEXP call, SEXP message) {
  Rf_errorcall(call, CHAR(STRING_ELT(message, 0)));
  return R_NilValue;
}
