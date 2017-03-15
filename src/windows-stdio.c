
#ifdef _WIN32

#include "windows-stdio.h"

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
    /* dwCreationDisposition = */ OPEN_ALWAYS,
    /* dwFlagsAndAttributes =  */ 0,
    /* hTemplateFile =         */ NULL);
  if (handle == INVALID_HANDLE_VALUE) { return GetLastError(); }

  *handle_ptr = handle;
  return 0;
}

int processx__stdio_create(const char *std_out, const char *std_err,
			   BYTE** buffer_ptr) {
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

  for (i = 0; i < count; i++) {
    DWORD access = (i == 0) ? FILE_GENERIC_READ :
      FILE_GENERIC_WRITE | FILE_READ_ATTRIBUTES;
    const char *output = i == 0 ? 0 : (i == 1 ? std_out : std_err);
    if (!output) {
      err = processx__create_nul_handle(&CHILD_STDIO_HANDLE(buffer, i), access);
    } else {
      err = processx__create_output_handle(&CHILD_STDIO_HANDLE(buffer, i),
					   output, access);
    }
    if (err) { goto error; }

    CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FDEV;
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
