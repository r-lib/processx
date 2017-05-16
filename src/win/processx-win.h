#ifndef R_PROCESSX_WIN_H
#define R_PROCESSX_WIN_H

#include <windows.h>

#include <Rinternals.h>

#include "../processx.h"

struct processx_handle_s;
typedef struct processx_pipe_handle_s {
  HANDLE pipe;
  OVERLAPPED overlapped;
  BYTE *buffer;
  DWORD buffer_size;
  BYTE *buffer_end;
  BOOLEAN read_pending;
  BOOLEAN EOF_signalled;
  char tail;
} processx_pipe_handle_t;

typedef struct processx_handle_s {
  int exitcode;
  int collected;	 /* Whether exit code was collected already */
  HANDLE job;
  HANDLE hProcess;
  DWORD  dwProcessId;
  BYTE *child_stdio_buffer;
  HANDLE waitObject;
  processx_pipe_handle_t *pipes[3];
  int cleanup;
} processx_handle_t;

extern HANDLE processx__iocp;

int uv_utf8_to_utf16_alloc(const char* s, WCHAR** ws_ptr);

int processx__stdio_create(processx_handle_t *handle,
			   const char *std_out, const char *std_err,
			   BYTE** buffer_ptr, SEXP private);
WORD processx__stdio_size(BYTE* buffer);
HANDLE processx__stdio_handle(BYTE* buffer, int fd);
void processx__stdio_destroy(BYTE* buffer);

void processx__handle_destroy(processx_handle_t *handle);

#define PROCESSX_ERROR(m,c) processx__error((m),(c),__FILE__,__LINE__)
void processx__error(const char *message, DWORD errorcode, const char *file, int line);

#endif
