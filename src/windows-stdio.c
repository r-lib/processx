
#ifdef _WIN32

#include "windows-stdio.h"

void processx__error(DWORD errorcode);

/*
 * The `child_stdio_buffer` buffer has the following layout:
 *   int number_of_fds
 *   unsigned char crt_flags[number_of_fds]
 *   HANDLE os_handle[number_of_fds]
 */
#define CHILD_STDIO_SIZE(count)                     \
    (sizeof(int) +                                  \
     sizeof(unsigned char) * (count) +              \
     sizeof(uintptr_t) * (count))

#define CHILD_STDIO_COUNT(buffer)                   \
    *((unsigned int*) (buffer))

#define CHILD_STDIO_CRT_FLAGS(buffer, fd)           \
    *((unsigned char*) (buffer) + sizeof(int) + fd)

#define CHILD_STDIO_HANDLE(buffer, fd)              \
    *((HANDLE*) ((unsigned char*) (buffer) +        \
                 sizeof(int) +                      \
                 sizeof(unsigned char) *            \
                 CHILD_STDIO_COUNT((buffer)) +      \
                 sizeof(HANDLE) * (fd)))

/* CRT file descriptor mode flags */
#define FOPEN       0x01
#define FEOFLAG     0x02
#define FCRLF       0x04
#define FPIPE       0x08
#define FNOINHERIT  0x10
#define FAPPEND     0x20
#define FDEV        0x40
#define FTEXT       0x80

static int processx__create_nul_handle(HANDLE *handle_ptr, DWORD access) {
  HANDLE handle;
  SECURITY_ATTRIBUTES sa;

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;

  handle = CreateFileW(
    /* lpFilename =            */ L"NUL",
    /* dwDesiredAccess=        */ access,
    /* dwShareMode =           */ FILE_SHARE_READ | FILE_SHARE_WRITE,
    /* lpSecurityAttributes =  */ &sa,
    /* dwCreationDisposition = */ OPEN_EXISTING,
    /* dwFlagsAndAttributes =  */ 0,
    /* hTemplateFile =         */ NULL);
  if (handle == INVALID_HANDLE_VALUE) { return GetLastError(); }

  *handle_ptr = handle;
  return 0;
}

static int processx__create_output_handle(HANDLE *handle_ptr, const char *file,
					  DWORD access) {
  HANDLE handle;
  SECURITY_ATTRIBUTES sa;
  int err;

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;
  WCHAR *filew;

  err = uv_utf8_to_utf16_alloc(file, &filew);
  if (err) return(err);

  handle = CreateFileW(
    /* lpFilename =            */ filew,
    /* dwDesiredAccess=        */ access,
    /* dwShareMode =           */ FILE_SHARE_READ | FILE_SHARE_WRITE,
    /* lpSecurityAttributes =  */ &sa,
    /* dwCreationDisposition = */ CREATE_ALWAYS,
    /* dwFlagsAndAttributes =  */ 0,
    /* hTemplateFile =         */ NULL);
  if (handle == INVALID_HANDLE_VALUE) { return GetLastError(); }

  /* We will append, so set pointer to end of file */
  SetFilePointer(handle, 0, NULL, FILE_END);

  *handle_ptr = handle;
  return 0;
}

static void processx__unique_pipe_name(char* ptr, char* name, size_t size) {
  snprintf(name, size, "\\\\?\\pipe\\px\\%p-%lu", ptr, GetCurrentProcessId());
}

int processx__create_pipe(processx_handle_t *handle,
			  HANDLE* parent_pipe_ptr,
			  HANDLE* child_pipe_ptr) {
  SECURITY_ATTRIBUTES sa;
  char pipe_name[64];
  HANDLE parent = NULL, child = NULL;
  DWORD err;
  char *ptr = (char*) handle;

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;  

  while (1) {
    processx__unique_pipe_name(ptr, pipe_name, sizeof(pipe_name));
  
    parent = CreateNamedPipeA(
      pipe_name,
      PIPE_ACCESS_INBOUND, //  | FILE_FLAG_OVERLAPPED,
      PIPE_TYPE_BYTE | PIPE_WAIT,
      1,
      4096,
      4096,
      0,
      NULL);

    /* Created successfully */
    if (parent != INVALID_HANDLE_VALUE) break;

    /* Some real error happened */
    err = GetLastError();
    if (err != ERROR_PIPE_BUSY) goto error;

    /* Just a name collisiom try again, with a slightly different name */
    ptr++;
  }

  child = CreateFileA(
    pipe_name,
    GENERIC_WRITE,
    0,
    &sa,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    NULL);

  if (child == INVALID_HANDLE_VALUE) {
    err = GetLastError();
    child = NULL;
    goto error;
  }

  *parent_pipe_ptr = parent;
  *child_pipe_ptr  = child;

  return 0;
  
 error:
  if (parent) CloseHandle(parent);
  if (child)  CloseHandle(child);

  processx__error(err);
  
  return 0;
}

void processx__con_destroy(Rconnection con) {
  if (con->status >= 0) {
    processx_handle_t *px = con->private;
    if (con->status == 1) {
      CloseHandle(px->stdout_pipe);
    } else {
      CloseHandle(px->stderr_pipe);
    }
  }
}

size_t processx__con_read(void *target, size_t sz, size_t ni,
			  Rconnection con) {
  int which = con->status;
  processx_handle_t *px = con->private;
  HANDLE pipe;
  DWORD bytes_read = 0, available;
  BOOLEAN result;

  if (which < 0) error("Connection was already closed");
  if (sz != 1) error("Can only read bytes from processx connections");
  if (which == 1) pipe = px->stdout_pipe; else pipe = px->stderr_pipe;

  con->incomplete = 1;
  
  result = PeekNamedPipe(
    /* hNamedPipe = */ pipe,
    /* lpBuffer = */ NULL,
    /* nBufferSize = */ 0,
    /* lpBytesRead = */ NULL,
    /* lpTotalBytesAvail = */ &available,
    /* lpBytesLeftThisMessage = */ NULL);

  if (!result) processx__error(GetLastError());

  if (available > 0) {
    result = ReadFile(
      /* hFile = */ pipe,
      /* lpBuffer = */ target,
      /* nNumberOfBytesToRead = */ sz * ni,
      /* lpNumberOfBytesRead = */ &bytes_read,
      /* lpOverlapped = */ NULL);

    if (!result) processx__error(GetLastError());
  }

  return (size_t) bytes_read;
}

int processx__con_fgetc(Rconnection con) {
  int x = 0;
#ifdef WORDS_BIGENDIAN
  return processx__con_read(&x, 1, 1, con) ? BSWAP_32(x) : -1;
#else
  return processx__con_read(&x, 1, 1, con) ? x : -1;
#endif
}

void processx__create_connection(processx_handle_t *handle,
				 HANDLE server_pipe, const char *membername,
				 int which, SEXP private) {

  Rconnection con;
  SEXP res =
    PROTECT(R_new_custom_connection("processx", "r", "textConnection", &con));

  con->incomplete = 1;
  con->private = handle;
  con->status = which;		/* slight abuse */
  con->canseek = 0;
  con->canwrite = 0;
  con->canread = 1;
  con->isopen = 1;
  con->blocking = 0;
  con->text = 1;
  con->UTF8out = 1;
  con->destroy = &processx__con_destroy;
  con->read = &processx__con_read;
  con->fgetc = &processx__con_fgetc;
  con->fgetc_internal = &processx__con_fgetc;

  defineVar(install(membername), res, private);
  UNPROTECT(1);
}

int processx__stdio_create(processx_handle_t *handle,
			   const char *std_out, const char *std_err,
			   BYTE** buffer_ptr, SEXP private) {
  BYTE* buffer;
  int count, i;
  int err;

  count = 3;

  buffer = malloc(CHILD_STDIO_SIZE(count));
  if (!buffer) { error("Out of memory"); }

  CHILD_STDIO_COUNT(buffer) = count;
  for (i = 0; i < count; i++) {
    CHILD_STDIO_CRT_FLAGS(buffer, i) = 0;
    CHILD_STDIO_HANDLE(buffer, i) = INVALID_HANDLE_VALUE;
  }

  handle->stdout_pipe = handle->stderr_pipe = 0;
  for (i = 0; i < count; i++) {
    DWORD access = (i == 0) ? FILE_GENERIC_READ :
      FILE_GENERIC_WRITE | FILE_READ_ATTRIBUTES;
    const char *output = i == 0 ? 0 : (i == 1 ? std_out : std_err);

    if (!output) {
      /* ignored output */
      err = processx__create_nul_handle(&CHILD_STDIO_HANDLE(buffer, i), access);
      if (err) { goto error; }
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FDEV;

    } else if (strcmp("|", output)) {
      /* output to file */
      err = processx__create_output_handle(&CHILD_STDIO_HANDLE(buffer, i),
					   output, access);
      if (err) { goto error; }
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FDEV;

    } else {
      /* piped output */
      const char *pipe_name = i == 1 ? "stdout_pipe" : "stderr_pipe";
      HANDLE *server_pipe = i == 1 ? &handle->stdout_pipe : &handle->stderr_pipe;
      err = processx__create_pipe(
        handle, server_pipe, &CHILD_STDIO_HANDLE(buffer, i)
      );
      if (err) { goto error; }
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FPIPE;
      processx__create_connection(handle, *server_pipe, pipe_name, i, private);
    }
  }

  *buffer_ptr  = buffer;
  return 0;

 error:
  free(buffer);
  return err;
}

WORD processx__stdio_size(BYTE* buffer) {
  return (WORD) CHILD_STDIO_SIZE(CHILD_STDIO_COUNT((buffer)));
}

HANDLE processx__stdio_handle(BYTE* buffer, int fd) {
  return CHILD_STDIO_HANDLE(buffer, fd);
}

#endif
