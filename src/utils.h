
#ifndef R_PROCESSX_UTILS_H
#define R_PROCESSX_UTILS_H

#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#include <Rinternals.h>

#include <string.h>

typedef struct {
  int detached;
  int windows_verbatim_args;
  int windows_hide;
} processx_options_t;

typedef struct {
#ifdef WIN32
  HANDLE hProcess;
  HANDLE hThread;
  DWORD  dwProcessId;
  DWORD  dwThreadId;
  BYTE *child_stdio_buffer;
#else
  pid_t pid
#endif
} processx_handle_t;

void processx__handle_destroy(processx_handle_t *handle);

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

#endif
