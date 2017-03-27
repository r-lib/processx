
#ifndef R_PROCESSX_UTILS_H
#define R_PROCESSX_UTILS_H

#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#include <Rinternals.h>

#include <R_ext/Connections.h>
#if ! defined(R_CONNECTIONS_VERSION) || R_CONNECTIONS_VERSION != 1
#error "Unsupported connections API version"
#endif

#include <string.h>

typedef struct {
  int detached;
  int windows_verbatim_args;
  int windows_hide;
} processx_options_t;

#ifdef WIN32
struct processx_handle_s;
typedef struct {
  HANDLE handle;
  OVERLAPPED overlapped;
  struct processx_handle_s *process;
  char buffer[65536];
  DWORD have_bytes;
} processx_pipe_t;
#endif

typedef struct processx_handle_s {
  int exitcode;
  int collected;    /* Whether exit code was collected already */
#ifdef WIN32
  HANDLE hProcess;
  DWORD  dwProcessId;
  BYTE *child_stdio_buffer;
  HANDLE waitObject;
  processx_pipe_t stdio[3];	/* stdin, stdout, stderr */
#else
  pid_t pid;
  int fd0;			/* writeable */
  int fd1;			/* readable */
  int fd2;			/* readable */
  int waitpipe[2];		/* use it for wait() with timeout */
#endif
} processx_handle_t;

typedef struct {
  processx_handle_t *handle;
  int which;			/* 0, 1 or 2 */
} processx_connection_t;

void processx__handle_destroy(processx_handle_t *handle);

char *processx__tmp_string(SEXP str, int i);
char **processx__tmp_character(SEXP chr);

#endif
