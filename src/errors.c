
#include "errors.h"

#include <Rinternals.h>

#ifndef _WIN32
#include <string.h>
#endif

#define ERRORBUF_SIZE 4096
static char errorbuf[ERRORBUF_SIZE];

SEXP r_throw_error(const char *func, const char *filename, int line,
                   const char *msg, ...) {
  va_list args;
  va_start(args, msg);
  vsnprintf(errorbuf, ERRORBUF_SIZE, msg, args);
  va_end (args);
  error("%s @%s:%d (%s)", errorbuf, filename, line, func);
  return R_NilValue;
}

#ifdef _WIN32

SEXP r_throw_system_error(const char *func, const char *filename, int line,
                          DWORD errorcode, const char *sysmsg,
                          const char *msg, ...) {

  va_list args;
  LPVOID lpMsgBuf;
  char *realsysmsg = sysmsg ? (char*) sysmsg : NULL;

  if (errorcode == -1) errorcode = GetLastError();

  if (!realsysmsg) {
    FormatMessage(
      FORMAT_MESSAGE_ALLOCATE_BUFFER |
      FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL,
      errorcode,
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      (LPTSTR) &lpMsgBuf,
      0, NULL);

    realsysmsg = R_alloc(1, strlen(lpMsgBuf) + 1);
    strcpy(realsysmsg, lpMsgBuf);
    LocalFree(lpMsgBuf);
  }

  va_start(args, msg);
  vsnprintf(errorbuf, ERRORBUF_SIZE, msg, args);
  va_end(args);
  error("%s (system error %d, %s) @%s:%d (%s)", errorbuf, errorcode,
        realsysmsg, filename, line, func);
  return R_NilValue;
}

#else

SEXP r_throw_system_error(const char *func, const char *filename, int line,
                          int errorcode, const char *sysmsg,
                          const char *msg, ...) {
  va_list args;
  if (!sysmsg) sysmsg = strerror(errorcode);
  va_start(args, msg);
  vsnprintf(errorbuf, ERRORBUF_SIZE, msg, args);
  va_end(args);
  error("%s (system error %d, %s) @%s:%d (%s)", errorbuf, errorcode, sysmsg,
        filename, line, func);
  return R_NilValue;
}

#endif
