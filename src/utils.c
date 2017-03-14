
#include "utils.h"

char *processx__tmp_string(SEXP str, int i) {
  const char *ptr = CHAR(STRING_ELT(str, i));
  char *cstr = R_alloc(1, strlen(ptr) + 1);
  strcpy(cstr, ptr);
  return cstr;
}

char **processx__tmp_character(SEXP chr) {
  size_t i, n = LENGTH(chr);
  char **cchr = (void*) R_alloc(n + 1, sizeof(char*));
  for (i = 0; i < n; i++) {
    cchr[i] = processx__tmp_string(chr, i);
  }
  cchr[n] = 0;
  return cchr;
}
