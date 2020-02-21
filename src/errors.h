
#ifndef R_THROW_ERROR_H
#define R_THROW_ERROR_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#endif

#include <Rinternals.h>

#define R_THROW_ERROR(...) \
  r_throw_error(__func__, __FILE__, __LINE__, __VA_ARGS__)

SEXP r_throw_error(const char *func, const char *filename, int line,
                   const char *msg, ...);

#ifdef _WIN32

#define R_THROW_SYSTEM_ERROR(...) \
  r_throw_system_error(__func__, __FILE__, __LINE__, (-1), NULL, __VA_ARGS__)
#define R_THROW_SYSTEM_ERROR_CODE(errorcode, ...)             \
  r_throw_system_error(__func__, __FILE__, __LINE__, (errorcode), NULL, __VA_ARGS__)

SEXP r_throw_system_error(const char *func, const char *filename, int line,
                          DWORD errorcode, const char *sysmsg,
                          const char *msg, ...);

SEXP r_throw_posix_error(const char *func, const char *filename, int line,
                         int errorcode, const char *sysmsg,
                         const char *msg, ...);

#define R_THROW_POSIX_ERROR(...)                                        \
  r_throw_posix_error(__func__, __FILE__, __LINE__, errno, NULL, __VA_ARGS__)
#define R_THROW_POSIX_ERROR_CODE(errorcode, ...)           \
  r_throw_posix_error(__func__, __FILE__, __LINE__, errorcode, NULL, __VA_ARGS__)


#else

#define R_THROW_SYSTEM_ERROR(...) \
  r_throw_system_error(__func__, __FILE__, __LINE__, errno, NULL, __VA_ARGS__)
#define R_THROW_SYSTEM_ERROR_CODE(errorcode, ...)           \
  r_throw_system_error(__func__, __FILE__, __LINE__, errorcode, NULL, __VA_ARGS__)

SEXP r_throw_system_error(const char *func, const char *filename, int line,
                          int errorcode, const char *sysmsg,
                          const char *msg, ...);
#endif

#endif
