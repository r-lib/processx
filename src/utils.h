
#ifndef R_PROCESSX_UTILS_H
#define R_PROCESSX_UTILS_H

#include <Rinternals.h>

#include <string.h>

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

#endif
