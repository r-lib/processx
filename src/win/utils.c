
#include "../processx.h"

SEXP processx_disable_crash_dialog() {
  /* TODO */
  return R_NilValue;
}

SEXP processx__echo_on() {
  error("Only implemented on Unix");
  return R_NilValue;
}

SEXP processx__echo_off() {
  error("Only implemented on Unix");
  return R_NilValue;
}
