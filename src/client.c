
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <Rinternals.h>
#include "errors.h"

#ifdef _WIN32

#include <windows.h>

/*
 * Clear the HANDLE_FLAG_INHERIT flag from all HANDLEs that were inherited
 * the parent process. Don't check for errors - the stdio handles may not be
 * valid, or may be closed already. There is no guarantee that this function
 * does a perfect job.
 */

SEXP processx_disable_inheritance() {
  HANDLE handle;
  STARTUPINFOW si;

  /* Make the windows stdio handles non-inheritable. */
  handle = GetStdHandle(STD_INPUT_HANDLE);
  if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
    SetHandleInformation(handle, HANDLE_FLAG_INHERIT, 0);
  }

  handle = GetStdHandle(STD_OUTPUT_HANDLE);
  if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
    SetHandleInformation(handle, HANDLE_FLAG_INHERIT, 0);
  }

  handle = GetStdHandle(STD_ERROR_HANDLE);
  if (handle != NULL && handle != INVALID_HANDLE_VALUE) {
    SetHandleInformation(handle, HANDLE_FLAG_INHERIT, 0);
  }

  /* Make inherited CRT FDs non-inheritable. */
  GetStartupInfoW(&si);
  if (processx__stdio_verify(si.lpReserved2, si.cbReserved2)) {
    processx__stdio_noinherit(si.lpReserved2);
  }

  return R_NilValue;
}

SEXP processx_write(SEXP fd, SEXP data) {
  int cfd = INTEGER(fd)[0];
  HANDLE h = (HANDLE) _get_osfhandle(fd);
  DWORD written;

  BOOL ret = WriteFile(h, RAW(data), LENGTH(data), &written, NULL);
  if (!ret) R_THROW_SYSTEM_ERROR("Cannot write to fd");

  return ScalarInteger(written);
}

#else

#include <fcntl.h>
#include <errno.h>
#include <unistd.h>

static int processx__cloexec_fcntl(int fd, int set) {
  int flags;
  int r;

  do { r = fcntl(fd, F_GETFD); } while (r == -1 && errno == EINTR);
  if (r == -1) { return -errno; }

  /* Bail out now if already set/clear. */
  if (!!(r & FD_CLOEXEC) == !!set) { return 0; }

  if (set) { flags = r | FD_CLOEXEC; } else { flags = r & ~FD_CLOEXEC; }

  do { r = fcntl(fd, F_SETFD, flags); } while (r == -1 && errno == EINTR);
  if (r) { return -errno; }

  return 0;
}

SEXP processx_disable_inheritance() {
  int fd;

  /* Set the CLOEXEC flag on all open descriptors. Unconditionally try the
   * first 16 file descriptors. After that, bail out after the first error.
   */
  for (fd = 0; ; fd++) {
    if (processx__cloexec_fcntl(fd, 1) && fd > 15) break;
  }

  return R_NilValue;
}

SEXP processx_write(SEXP fd, SEXP data) {
  int cfd = INTEGER(fd)[0];

  ssize_t ret = write(cfd, RAW(data), LENGTH(data));
  if (ret == -1) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      ret = 0;
    } else {
      R_THROW_SYSTEM_ERROR("Cannot write to fd");
    }
  }

  return ScalarInteger(ret);
}

#endif
