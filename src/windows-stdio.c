
#ifdef _WIN32

#include "windows-stdio.h"

HANDLE processx__iocp = NULL;

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

void processx__unique_pipe_name(char *ptr, char *name, size_t size) {
  snprintf(name, size, "\\\\?\\pipe\\uv\\%p-%lu", ptr, GetCurrentProcessId());
}

int processx__stdio_pipe_server(processx_handle_t *handle,
				HANDLE *server_pipe, DWORD access, char* name,
				int nameSize) {
  HANDLE pipeHandle;
  HANDLE iocp;
  int err;

  for (;;) {
    processx__unique_pipe_name((char*) handle, name, nameSize);

    pipeHandle = CreateNamedPipeA(
      name, access | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
      1, 65536, 65536, 0, NULL);

    if (pipeHandle != INVALID_HANDLE_VALUE) break;

    err = GetLastError();
    if (err != ERROR_PIPE_BUSY && err != ERROR_ACCESS_DENIED) goto error;

    /* Otherwise try again */
  }

  iocp = CreateIoCompletionPort(pipeHandle, processx__iocp, (ULONG_PTR)handle, 0);
  if (!processx__iocp) processx__iocp = iocp;

  if (!iocp) {
    err = GetLastError();
    goto error;
  }

  *server_pipe = pipeHandle;
  return 0;

 error:
  if (pipeHandle != INVALID_HANDLE_VALUE) {
    CloseHandle(pipeHandle);
  }
  return err;
}

 int processx__create_stdio_pipe_pair(processx_handle_t *handle,
				      HANDLE* parent_pipe_ptr,
				      HANDLE* child_pipe_ptr) {
  char pipe_name[64];
  SECURITY_ATTRIBUTES sa;
  DWORD server_access = 0;
  DWORD client_access = 0;
  HANDLE child_pipe = INVALID_HANDLE_VALUE;
  int err;

  /* The server needs inbound access too, otherwise CreateNamedPipe() */
  /* won't give us the FILE_READ_ATTRIBUTES permission. We need that to */
  /* probe the state of the write buffer when we're trying to shutdown */
  /* the pipe. */
  server_access |= PIPE_ACCESS_OUTBOUND | PIPE_ACCESS_INBOUND;
  client_access |= GENERIC_READ | FILE_WRITE_ATTRIBUTES | PIPE_ACCESS_OUTBOUND;

  err = processx__stdio_pipe_server(handle, parent_pipe_ptr, server_access,
				    pipe_name, sizeof(pipe_name));
  if (err) goto error;

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;

  child_pipe = CreateFileA(pipe_name, client_access, 0, &sa, OPEN_EXISTING,
			   FILE_FLAG_OVERLAPPED, NULL);
  if (child_pipe == INVALID_HANDLE_VALUE) {
    err = GetLastError();
    goto error;
  }

  if (!ConnectNamedPipe(*parent_pipe_ptr, NULL)) {
    if (GetLastError() != ERROR_PIPE_CONNECTED) {
      err = GetLastError();
      goto error;
    }
  }

  *child_pipe_ptr = child_pipe;

 error:
  if (*parent_pipe_ptr != INVALID_HANDLE_VALUE) {
    CloseHandle(*parent_pipe_ptr);
  }
  if (child_pipe != INVALID_HANDLE_VALUE) {
    CloseHandle(child_pipe);
  }
  return err;
}

void processx__con_destroy(Rconnection con) {
  processx_handle_t *px = con->private;
  int which = con->status;
  processx_pipe_t *pipe = &px->stdio[which];
  if (!pipe->handle) return;

  CloseHandle(pipe->handle);
  if (pipe->overlapped.hEvent) CloseHandle(pipe->overlapped.hEvent);
  pipe->handle = pipe->overlapped.hEvent = 0;
}

void processx__con_read_again(processx_pipe_t *pipe) {
  BOOLEAN result;
  DWORD bytes_read, err;

  result = ReadFile(pipe->handle, pipe->buffer, sizeof(pipe->buffer),
		    &bytes_read, &pipe->overlapped);
  if (result) {
    /* Finished synchronously... */
    pipe->have_bytes = bytes_read;

  } else {
    err = GetLastError();
    if (err == ERROR_HANDLE_EOF) {
      /* Finished with EOF, we might as well close the pipe */
      pipe->have_bytes = bytes_read;
      CloseHandle(pipe->handle);
      if (pipe->overlapped.hEvent) CloseHandle(pipe->overlapped.hEvent);
      pipe->handle = pipe->overlapped.hEvent = 0;

    } else if (err == ERROR_IO_PENDING) {
      /* IO pending, this is the normal behavior at this point.
	 We don't need to do anything now, the next GetOverlappedResult()
	 will collect the result of the read. */

    } else {
      processx__error(err);
    }
  }
}

size_t processx__con_read(void *target, size_t sz, size_t ni,
			  Rconnection con) {
  processx_handle_t *px = con->private;
  int which = con->status;
  processx_pipe_t *pipe = &px->stdio[which];
  BOOLEAN result;
  DWORD bytes_read, err;
  if (!pipe->handle) return 0;

  REprintf("Connection read\n");

  /* If we already have something, we just return that, and start reading again. */
  if (pipe->have_bytes) {
    REprintf("Reading.... have %d bytes already\n", (int) pipe->have_bytes);
    size_t num_bytes_to_copy = sz * ni >= pipe->have_bytes ? pipe->have_bytes : sz * ni;
    memcpy(target, pipe->buffer, num_bytes_to_copy);
    pipe->have_bytes -= num_bytes_to_copy;
    if (pipe->have_bytes) {
      memmove(pipe->buffer, pipe->buffer + num_bytes_to_copy, pipe->have_bytes);
    }
    if (!pipe->have_bytes && pipe->handle) processx__con_read_again(pipe);
    return num_bytes_to_copy;
  }

  result = GetOverlappedResult(pipe->handle, &pipe->overlapped, &bytes_read, FALSE);
  if (result) {
    /* Finished */
    REprintf("Read finished, got %d bytes\n", (int) bytes_read);
    size_t num_bytes_to_copy = sz * ni >= bytes_read ? bytes_read : sz * ni;
    memcpy(target, pipe->buffer, num_bytes_to_copy);
    pipe->have_bytes = bytes_read - num_bytes_to_copy;
    if (pipe->have_bytes) {
      memmove(pipe->buffer, pipe->buffer + num_bytes_to_copy, pipe->have_bytes);
    }

    ResetEvent(pipe->overlapped.hEvent);
    if (!pipe->have_bytes) processx__con_read_again(pipe);

    return num_bytes_to_copy;

  } else {
    err = GetLastError();
    if (err == ERROR_HANDLE_EOF) {
      /* Finished with EOF, we might as well close the pipe */
      REprintf("Read finished with EOF, got %d bytes\n", (int) bytes_read);
      size_t num_bytes_to_copy = sz * ni >= bytes_read ? bytes_read : sz * ni;
      memcpy(target, pipe->buffer, num_bytes_to_copy);
      pipe->have_bytes = bytes_read - num_bytes_to_copy;
      if (pipe->have_bytes) {
	memmove(pipe->buffer, pipe->buffer + num_bytes_to_copy, pipe->have_bytes);
      }

      CloseHandle(pipe->handle);
      if (pipe->overlapped.hEvent) CloseHandle(pipe->overlapped.hEvent);
      pipe->handle = pipe->overlapped.hEvent = 0;

      return num_bytes_to_copy;

    } else if (err == ERROR_IO_INCOMPLETE) {
      REprintf("Nothing yet\n");
      /* Nothing yet, just return 0 */
      return 0;

    } else {
      /* Some error */
      processx__error(err);
      return 0;			/* never reached */
    }
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

void processx__create_connection(processx_handle_t *handle, HANDLE parent_pipe_str,
				 const char *pipe_name, int which, SEXP private) {
  Rconnection con;
  SEXP res =
    PROTECT(R_new_custom_connection("processx", "r", "textConnection", &con));

  con->incomplete = 1;
  con->private = handle;
  con->status = which;		/* 1 - stdout, 2 - stderr */
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

  defineVar(install(pipe_name), res, private);
  UNPROTECT(1);
}

DWORD processx__stdio_start_reading_pipes(processx_handle_t *handle) {
  int i;
  for (i = 1; i < 3; i++) {
    BOOLEAN result;
    processx_pipe_t *pipe = &handle->stdio[i];
    DWORD bytes_read, err;
    if (! pipe->handle) continue;

    pipe->have_bytes = 0;
    result = ReadFile(pipe->handle, pipe->buffer, sizeof(pipe->buffer),
		      &bytes_read, &pipe->overlapped);

    REprintf("start reading: %d\n", (int) result);

    if (result) {
      /* Finished synchronously (!) */
      REprintf("Read %d bytes\n", (int) bytes_read);
      pipe->have_bytes = bytes_read;

    } else {
      err = GetLastError();
      if (err == ERROR_HANDLE_EOF) {
	/* Finished with EOF, we might as well close the pipe */
	REprintf("EOF (%d bytes)\n", (int) bytes_read);
	pipe->have_bytes = bytes_read;
	CloseHandle(pipe->handle);
	if (pipe->overlapped.hEvent) CloseHandle(pipe->overlapped.hEvent);
	pipe->handle = pipe->overlapped.hEvent = 0;

      } else if (err == ERROR_IO_PENDING) {
	REprintf("IO pending\n");
	/* IO pending, this is the normal behavior at this point.
	   We don't need to do anything now, the next GetOverlappedResult()
	   will collect the result of the read. */

      } else {
	return err;
      }
    }
  }
  return 0;
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
    processx_pipe_t *pipe = &handle->stdio[i];
    pipe->handle = NULL;
    memset(&pipe->overlapped, 0, sizeof(pipe->overlapped));
    pipe->process = handle;
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
      err = processx__create_stdio_pipe_pair(
        handle, &pipe->handle, &CHILD_STDIO_HANDLE(buffer, i)
      );
      if (err) { goto error; }
      CHILD_STDIO_CRT_FLAGS(buffer, i) = FOPEN | FPIPE;
      pipe->overlapped.hEvent = CreateEvent(
        /* lpEventAttributes = */ NULL,
	/* bManualReset = */ TRUE,
	/* bInitialState = */ FALSE,
	/* lpName = */ NULL);
      if (!pipe->overlapped.hEvent) processx__error(GetLastError());
      processx__create_connection(handle, pipe->handle, pipe_name, i, private);
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
