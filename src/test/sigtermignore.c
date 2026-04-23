#ifndef _WIN32

#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <signal.h>

void R_init_sigtermignore(DllInfo *dll) {
  signal(SIGTERM, SIG_IGN);
}

// work around R CMD check false positive

void dummy() {
  R_registerRoutines(NULL, NULL, NULL, NULL, NULL);
  R_useDynamicSymbols(NULL, FALSE);
}

#endif
