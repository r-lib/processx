
#ifdef _WIN32

#include <R.h>

#include "processx-win.h"

/* Why is this not defined??? */
BOOL WINAPI CancelIoEx(
  HANDLE       hFile,
  LPOVERLAPPED lpOverlapped
);

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

  err = processx__utf8_to_utf16_alloc(file, &filew);
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

int processx__create_pipe(void *id, HANDLE* parent_pipe_ptr, HANDLE* child_pipe_ptr) {

  char pipe_name[40];
  HANDLE hOutputRead = INVALID_HANDLE_VALUE;
  HANDLE hOutputWrite = INVALID_HANDLE_VALUE;
  SECURITY_ATTRIBUTES sa;
  DWORD err;
  char *errmessage = "";

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;

  processx__unique_pipe_name(id, pipe_name, sizeof(pipe_name));

  hOutputRead = CreateNamedPipeA(
    pipe_name,
    PIPE_ACCESS_OUTBOUND | PIPE_ACCESS_INBOUND |
      FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
    PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
    1,
    65536,
    65536,
    0,
    NULL);
  if (hOutputRead == INVALID_HANDLE_VALUE) {
    err = GetLastError();
    errmessage = "creating read pipe";
    goto error;
  }

  hOutputWrite = CreateFileA(
    pipe_name,
    GENERIC_WRITE,
    0,
    &sa,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    NULL);
  if (hOutputWrite == INVALID_HANDLE_VALUE) {
    err = GetLastError();
    errmessage = "creating write pipe";
    goto error;
  }

  *parent_pipe_ptr = hOutputRead;
  *child_pipe_ptr  = hOutputWrite;

  return 0;

 error:
  if (hOutputRead != INVALID_HANDLE_VALUE) CloseHandle(hOutputRead);
  if (hOutputWrite != INVALID_HANDLE_VALUE) CloseHandle(hOutputWrite);
  PROCESSX_ERROR(errmessage, err);
  return 0;			/* never reached */
}



int processx__create_connection(processx_handle_t *handle, HANDLE pipe_handle,
				const char *membername, SEXP private,
				processx_connection_t **conptr) {

  processx_connection_t *con;
  SEXP res;

  con = malloc(sizeof(processx_connection_t));
  if (!con) error("out of memory");

  res = PROTECT(processx_connection_new(con));
  con->handle = pipe_handle;

  /* Need a manual event for async IO */
  con->overlapped.hEvent = CreateEvent(
    /* lpEventAttributes = */ NULL,
    /* bManualReset = */ FALSE,
    /* bInitialState = */ FALSE,
    /* lpName = */ NULL);

  if (con->overlapped.hEvent == NULL) {
    free(con);
    return GetLastError();
  }

  defineVar(install(membername), res, private);

  *conptr = con;

  UNPROTECT(1);
  return 0;
}

int processx__stdio_create(processx_handle_t *handle,
			   const char *std_out, const char *std_err,
			   BYTE** buffer_ptr, SEXP private) {
  BYTE* buffer;
  int count, i;
  int err;

  HANDLE pipe_handle[3] = { 0, 0, 0 };
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

    handle->pipes[i] = 0;

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
      processx_connection_t *con = 0;
      const char *r_pipe_name = i == 1 ? "stdout_pipe" : "stderr_pipe";
      GetRNGstate();
      err = processx__create_pipe(handle + (int)(unif_rand() * 65000),
				  &pipe_handle[i], &CHILD_STDIO_HANDLE(buffer, i));
      PutRNGstate();
      if (err) goto error;
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FPIPE;
      err = processx__create_connection(handle, pipe_handle[i], r_pipe_name, private, &con);
      if (err) { goto error; }
      handle->pipes[i] = con;
    }
  }

  *buffer_ptr  = buffer;
  return 0;

 error:
  free(buffer);
  for (i = 0; i < count; i++) {
    if (pipe_handle[i]) CloseHandle(pipe_handle[i]);
    if (handle->pipes[i]) free(handle->pipes[i]);
  }
  return err;
}

void processx__stdio_destroy(BYTE* buffer) {
  int i, count;

  count = CHILD_STDIO_COUNT(buffer);
  for (i = 0; i < count; i++) {
    HANDLE handle = CHILD_STDIO_HANDLE(buffer, i);
    if (handle != INVALID_HANDLE_VALUE) {
      CloseHandle(handle);
    }
  }

  free(buffer);
}

WORD processx__stdio_size(BYTE* buffer) {
  return (WORD) CHILD_STDIO_SIZE(CHILD_STDIO_COUNT((buffer)));
}

HANDLE processx__stdio_handle(BYTE* buffer, int fd) {
  return CHILD_STDIO_HANDLE(buffer, fd);
}

SEXP processx_poll_io(SEXP status, SEXP ms, SEXP rstdout_pipe, SEXP rstderr_pipe) {
  int cms = INTEGER(ms)[0], timeleft = cms;
  processx_handle_t *px = R_ExternalPtrAddr(status);
  SEXP result;
  DWORD waitres;
  HANDLE wait_handles[2];
  DWORD nCount = 0;
  int ptr1 = -1, ptr2 = -1;

  if (!px) { error("Internal processx error, handle already removed"); }

  result = PROTECT(allocVector(INTSXP, 2));

  /* See if there is anything to do */
  if (isNull(rstdout_pipe)) {
    INTEGER(result)[0] = PXNOPIPE;
  } else if (! px->pipes[1]) {
    INTEGER(result)[0] = PXCLOSED;
  } else {
    nCount ++;
    INTEGER(result)[0] = PXSILENT;
  }

  if (isNull(rstderr_pipe)) {
    INTEGER(result)[1] = PXNOPIPE;
  } else if (! px->pipes[2]) {
    INTEGER(result)[1] = PXCLOSED;
  } else {
    nCount ++;
    INTEGER(result)[1] = PXSILENT;
  }

  if (nCount == 0) {
    UNPROTECT(1);
    return result;
  }

  /* -------------------------------------------------------------------- */
  /* Check if there is anything available in the buffers */
  if (INTEGER(result)[0] == PXSILENT) {
    if (processx_connection_ready(px->pipes[1])) INTEGER(result)[0] = PXREADY;
  }
  if (INTEGER(result)[1] == PXSILENT) {
    if (processx_connection_ready(px->pipes[2])) INTEGER(result)[1] = PXREADY;
  }

  if (INTEGER(result)[0] == PXREADY || INTEGER(result)[1] == PXREADY) {
    UNPROTECT(1);
    return result;
  }

  /* For each pipe that does not have IO pending, start an async read */
  if (INTEGER(result)[0] == PXSILENT && ! px->pipes[1]->read_pending) {
    processx_connection_start_read(px->pipes[1], INTEGER(result));
  }

  if (INTEGER(result)[1] == PXSILENT && ! px->pipes[2]->read_pending) {
    processx_connection_start_read(px->pipes[2], INTEGER(result) + 1);
  }

  if (INTEGER(result)[0] == PXREADY || INTEGER(result)[1] == PXREADY) {
    UNPROTECT(1);
    return result;
  }

  /* If we are still alive, then we have some pending reads. Wait on them. */
  nCount = 0;
  if (INTEGER(result)[0] == PXSILENT) {
    if (px->pipes[1]->overlapped.hEvent) {
      ptr1 = nCount;
      wait_handles[nCount++] = px->pipes[1]->overlapped.hEvent;
    } else {
      INTEGER(result)[0] = PXCLOSED;
    }
  }
  if (INTEGER(result)[1] == PXSILENT) {
    if (px->pipes[2]->overlapped.hEvent) {
      ptr2 = nCount;
      wait_handles[nCount++] = px->pipes[2]->overlapped.hEvent;
    } else {
      INTEGER(result)[1] = PXCLOSED;
    }
  }

  /* Anything to wait for? */
  if (nCount == 0) {
    UNPROTECT(1);
    return result;
  }

  /* We need to wait in small intervals, to allow interruption from R */
  waitres = WAIT_TIMEOUT;
  while (cms < 0 || timeleft > PROCESSX_INTERRUPT_INTERVAL) {
    waitres = WaitForMultipleObjects(
      nCount,
      wait_handles,
      /* bWaitAll = */ FALSE,
      PROCESSX_INTERRUPT_INTERVAL);

    if (waitres != WAIT_TIMEOUT) break;

    R_CheckUserInterrupt();
    timeleft -= PROCESSX_INTERRUPT_INTERVAL;
  }

  /* Maybe we are not done, and there is a little left from the timeout */
  if (waitres == WAIT_TIMEOUT && timeleft >= 0) {
    waitres = WaitForMultipleObjects(
      nCount,
      wait_handles,
      /* bWaitAll = */ FALSE,
      timeleft);
  }

  if (waitres == WAIT_FAILED){
    PROCESSX_ERROR("wait when polling for io", GetLastError());
  } else if (waitres == WAIT_TIMEOUT) {
    if (ptr1 >= 0) INTEGER(result)[0] = PXTIMEOUT;
    if (ptr2 >= 0) INTEGER(result)[1] = PXTIMEOUT;
  } else {
    int ready = waitres - WAIT_OBJECT_0;
    if (ptr1 == ready) INTEGER(result)[0] = PXREADY;
    if (ptr2 == ready) INTEGER(result)[1] = PXREADY;
  }

  UNPROTECT(1);
  return result;
}

#endif
