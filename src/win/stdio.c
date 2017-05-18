
#ifdef _WIN32

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

  char pipe_name[40];
  HANDLE hOutputRead = INVALID_HANDLE_VALUE;
  HANDLE hOutputWrite = INVALID_HANDLE_VALUE;
  SECURITY_ATTRIBUTES sa;
  DWORD err;
  char *errmessage = "";

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;

  processx__unique_pipe_name((char*) parent_pipe_ptr, pipe_name, sizeof(pipe_name));

  hOutputRead = CreateNamedPipeA(
    pipe_name,
    PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED,
    PIPE_TYPE_BYTE | PIPE_WAIT,
    1,
    4096,
    4096,
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

void processx__con_destroy(Rconnection con) {
  processx_pipe_handle_t *handle = con->private;
  if (handle && handle->pipe) {

    /* Cancel pending IO and wait until cancellation is done */
    if (handle->read_pending) {
      if (CancelIoEx(handle->pipe, &handle->overlapped)) {
	DWORD bytes;
	GetOverlappedResult(handle->pipe, &handle->overlapped, &bytes, TRUE);
      }
    }
    handle->read_pending = FALSE;

    CloseHandle(handle->pipe);
    CloseHandle(handle->overlapped.hEvent);
    handle->pipe = NULL;
    if (handle->buffer) {
      free(handle->buffer);
      handle->buffer = 0;
    }
  }
}

size_t processx__con_read(void *target, size_t sz, size_t ni,
			  Rconnection con) {
  processx_pipe_handle_t *handle = con->private;
  HANDLE pipe = handle->pipe;
  DWORD bytes_read = 0;
  BOOLEAN result;
  size_t have_already;

  if (!pipe) error("Connection was closed already");
  if (sz != 1) error("Can only read bytes from processx connections");

  /* Already seen an EOF? Maybe in the poll, which does not update con? */
  if (handle->EOF_signalled) {
    con->EOF_signalled = 1;
    con->incomplete = 0;
    return 0;
  }

  con->incomplete = 1;

  /* Do we have something to return already? */
  have_already = handle->buffer_end - handle->buffer;

  /* Do we have too much? */
  if (have_already > sz * ni) {
    memcpy(target, handle->buffer, sz * ni);
    memmove(handle->buffer, handle->buffer + sz * ni,
	     have_already - sz * ni);
    handle->buffer_end = handle->buffer + have_already - sz * ni;
    if (sz * ni > 0) handle->tail = ((char*)target)[sz * ni - 1];
    return sz * ni;

  } else if (have_already > 0) {
    memcpy(target, handle->buffer, have_already);
    handle->buffer_end = handle->buffer;
    handle->tail = ((char*)target)[have_already - 1];
    return have_already;
  }

  /* We don't have anything. If there is no read pending, we
     start one. It might return synchronously, the little bastard. */
  if (! handle->read_pending) {
    handle->overlapped.Offset = 0;
    handle->overlapped.OffsetHigh = 0;
    result = ReadFile(
      pipe,
      handle->buffer,
      sz * ni < handle->buffer_size ? sz * ni : handle->buffer_size,
      NULL,
      &handle->overlapped);

    if (!result) {
      DWORD err = GetLastError();
      if (err == ERROR_BROKEN_PIPE) {
	con->incomplete = 0;
	con->EOF_signalled = 1;
	handle->EOF_signalled = 1;
	if (handle->tail != '\n') {
	  ((char*)target)[0] = '\n';
	  return 1;
	}
	return 0;
      } else if (err == ERROR_IO_PENDING) {
	handle->read_pending = TRUE;
      } else {
	PROCESSX_ERROR("reading from connection", err);
	return 0;		/* neve called */
      }
    } else {
      /* Returned without ERROR_IO_PENDING. Anyway, still must be pending,
	 because we set lpNumberOfBytesRead to a NULL pointer, so there is
	 no way to return the result synchronously. */
      handle->read_pending = TRUE;
    }
  }

  /* There is a read pending at this point.
     See if it has finished. */

  result = GetOverlappedResult(
    pipe,
    &handle->overlapped,
    &bytes_read,
    FALSE);

  if (!result) {
    DWORD err = GetLastError();
    if (err == ERROR_BROKEN_PIPE) {
      handle->read_pending = FALSE;
      con->incomplete = 0;
      con->EOF_signalled = 1;
      handle->EOF_signalled = 1;
      if (handle->tail != '\n') {
	((char*)target)[0] = '\n';
	return 1;
      }
      return 0;

    } else if (err == ERROR_IO_INCOMPLETE) {
      return 0;

    } else {
      handle->read_pending = FALSE;
      PROCESSX_ERROR("getting overlapped result in connection read", err);
      return 0;			/* never called */
    }

  } else {
    handle->read_pending = FALSE;
    if (sz * ni >= bytes_read) {
      memcpy(target, handle->buffer, bytes_read);
      if (bytes_read > 0) handle->tail = ((char*)target)[bytes_read - 1];
    } else {
      memcpy(target, handle->buffer, sz * ni);
      memmove(handle->buffer, handle->buffer + sz * ni,
	      bytes_read - sz * ni);
      handle->buffer_end = handle->buffer + bytes_read - sz * ni;
      if (sz * ni > 0) handle->tail = ((char*)target)[sz * ni - 1];
    }
    return bytes_read;
  }
}

int processx__con_fgetc(Rconnection con) {
  int x = 0;
#ifdef WORDS_BIGENDIAN
  return processx__con_read(&x, 1, 1, con) ? BSWAP_32(x) : -1;
#else
  return processx__con_read(&x, 1, 1, con) ? x : -1;
#endif
}

void processx__create_connection(processx_pipe_handle_t *handle,
				 const char *membername,
				 SEXP private) {

  Rconnection con;
  SEXP res =
    PROTECT(R_new_custom_connection("processx", "r", "textConnection", &con));

  handle->tail = '\n';

  con->incomplete = 1;
  con->private = handle;
  con->canseek = 0;
  con->canwrite = 0;
  con->canread = 1;
  con->isopen = 1;
  con->blocking = 0;
  con->text = 1;
  con->UTF8out = 1;
  con->EOF_signalled = 0;
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
      processx_pipe_handle_t *pipe = handle->pipes[i] = malloc(sizeof(processx_pipe_handle_t));
      const char *r_pipe_name = i == 1 ? "stdout_pipe" : "stderr_pipe";
      pipe->EOF_signalled = 0;
      err = processx__create_pipe(
        handle, &pipe->pipe, &CHILD_STDIO_HANDLE(buffer, i)
      );
      if (err) { goto error; }
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FPIPE;

      /* Allocate buffer for pipe */
      pipe->buffer_size = 256 * 256;
      pipe->buffer = malloc(pipe->buffer_size);
      if (!pipe->buffer) { goto error; }
      pipe->buffer_end = pipe->buffer;
      pipe->read_pending = FALSE;

      /* Need a manual event for async IO */
      pipe->overlapped.hEvent = CreateEvent(
        /* lpEventAttributes = */ NULL,
	/* bManualReset = */ FALSE,
	/* bInitialState = */ FALSE,
	/* lpName = */ NULL);

      if (pipe->overlapped.hEvent == NULL) {
	err = GetLastError();
	goto error;
      }

      /* Create R connection for it */
      processx__create_connection(pipe, r_pipe_name, private);
    }
  }

  *buffer_ptr  = buffer;
  return 0;

 error:
  free(buffer);
  for (i = 0; i < count; i++) {
    if (handle->pipes[i]) {
      if (handle->pipes[i]->buffer) free(handle->pipes[i]->buffer);
      if (handle->pipes[i]->overlapped.hEvent) {
	CloseHandle(handle->pipes[i]->overlapped.hEvent);
      }
      free(handle->pipes[i]);
    }
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

DWORD processx__poll_start_read(processx_pipe_handle_t *handle, int *result) {
  BOOLEAN res;
  handle->overlapped.Offset = 0;
  handle->overlapped.OffsetHigh = 0;
  res = ReadFile(
    handle->pipe,
    handle->buffer,
    handle->buffer_size,
    NULL,
    &handle->overlapped);

  if (!res) {
    DWORD err = GetLastError();
    if (err == ERROR_BROKEN_PIPE) {
      handle->EOF_signalled = 1;
      *result = PXREADY;
    } else if (err == ERROR_IO_PENDING) {
      handle->read_pending = TRUE;
    } else {
      return err;
    }
  } else {
    /* Returned without ERROR_IO_PENDING. Anyway, still must be pending,
       because we set lpNumberOfBytesRead to a NULL pointer, so there is
       no way to return the result synchronously. */
    /* returnd synchronously */
    handle->read_pending = TRUE;
  }

  return 0;
}

SEXP processx_poll_io(SEXP status, SEXP ms, SEXP rstdout_pipe, SEXP rstderr_pipe) {
  int cms = INTEGER(ms)[0], timeleft = cms;
  processx_handle_t *px = R_ExternalPtrAddr(status);
  SEXP result;
  DWORD err = 0;
  DWORD waitres;
  HANDLE wait_handles[2];
  DWORD nCount = 0;
  int ptr1 = -1, ptr2 = -1;
  char *errmessage = "";

  if (!px) { error("Internal processx error, handle already removed"); }

  result = PROTECT(allocVector(INTSXP, 2));

  /* See if there is anything to do */
  if (isNull(rstdout_pipe)) {
    INTEGER(result)[0] = PXNOPIPE;
  } else if (! px->pipes[1] || ! px->pipes[1]->pipe || !px->pipes[1]->buffer) {
    INTEGER(result)[0] = PXCLOSED;
  } else {
    nCount ++;
    INTEGER(result)[0] = PXSILENT;
  }

  if (isNull(rstderr_pipe)) {
    INTEGER(result)[1] = PXNOPIPE;
  } else if (! px->pipes[2] || ! px->pipes[2]->pipe || !px->pipes[2]->buffer) {
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
    processx_pipe_handle_t *handle = px->pipes[1];
    if (handle->buffer_end > handle->buffer) INTEGER(result)[0] = PXREADY;
  }
  if (INTEGER(result)[1] == PXSILENT) {
    processx_pipe_handle_t *handle = px->pipes[2];
    if (handle->buffer_end > handle->buffer) INTEGER(result)[1] = PXREADY;
  }

  if (INTEGER(result)[0] == PXREADY || INTEGER(result)[1] == PXREADY) {
    UNPROTECT(1);
    return result;
  }

  /* For each pipe that does not have IO pending, start an async read */
  if (INTEGER(result)[0] == PXSILENT && ! px->pipes[1]->read_pending) {
    err = processx__poll_start_read(px->pipes[1], INTEGER(result));
    if (err) { errmessage = "start read for poll stdout"; goto laberror; }
  }

  if (INTEGER(result)[1] == PXSILENT && ! px->pipes[2]->read_pending) {
    err = processx__poll_start_read(px->pipes[2], INTEGER(result) + 1);
    if (err) { errmessage = "start read for poll stderr"; goto laberror; }
  }

  if (INTEGER(result)[0] == PXREADY || INTEGER(result)[1] == PXREADY) {
    UNPROTECT(1);
    return result;
  }

  /* If we are still alive, then we have some pending reads. Wait on them. */
  nCount = 0;
  if (INTEGER(result)[0] == PXSILENT) {
    ptr1 = nCount;
    wait_handles[nCount++] = px->pipes[1]->overlapped.hEvent;
  }
  if (INTEGER(result)[1] == PXSILENT) {
    ptr2 = nCount;
    wait_handles[nCount++] = px->pipes[2]->overlapped.hEvent;
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

  if (waitres == WAIT_FAILED) {
    err = GetLastError();
    errmessage = "wait when polling for io";
    goto laberror;
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

 laberror:
  PROCESSX_ERROR(errmessage, err);
  return R_NilValue;		/* never called */
}

#endif
