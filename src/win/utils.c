
#include "../processx.h"

SEXP processx_disable_crash_dialog() {
  /* TODO */
  return R_NilValue;
}

SEXP processx__echo_on() {
  R_THROW_ERROR("Only implemented on Unix");
  return R_NilValue;
}

SEXP processx__echo_off() {
  R_THROW_ERROR("Only implemented on Unix");
  return R_NilValue;
}

SEXP processx__mmap_pack(SEXP filename, SEXP data) {
  error("Only implemented on Unix");
  return R_NilValue;
}

SEXP processx__mmap_unpack(SEXP fd) {
  error("Only implemented on Unix");
  return R_NilValue;
}
