
#ifndef R_PROCESSX_UTILS_H
#define R_PROCESSX_UTILS_H

#include <Rinternals.h>

#include <string.h>

typedef struct {
  int detached;
  int windows_verbatim_args;
  int windows_hide;
} processx_options_t;

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

#endif
