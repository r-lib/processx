#ifndef _WIN32

#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <signal.h>

void R_init_sigtermignore(DllInfo *dll) {
  signal(SIGTERM, SIG_IGN);
}

#endif
