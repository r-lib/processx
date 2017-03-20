
#include <stdlib.h>

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

void processx__handle_destroy(processx_handle_t *handle) {
  if (!handle) return;
#ifdef WIN
  if (handle->child_stdio_buffer) free(handle->child_stdio_buffer);
#else
  /* Nothing to do currently */
#endif
  free(handle);
}

