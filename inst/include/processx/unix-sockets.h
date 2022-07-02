#ifndef R_CLI_PROGRESS_H
#define R_CLI_PROGRESS_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#include <windows.h>
#include <io.h>
typedef HANDLE processx_socket_t;
#else
#include <sys/socket.h>
#include <sys/un.h>
#include <string.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
typedef int processx_socket_t;
#endif

#ifndef PROCESSX_STATIC
#define PROCESSX_STATIC static
#endif
  
PROCESSX_STATIC int processx_socket_connect(const char *filename,
                                            processx_socket_t *pxsocket) {
#ifdef _WIN32
  HANDLE hnd;
  SECURITY_ATTRIBUTES sa;
  DWORD access = GENERIC_READ | GENERIC_WRITE;
  DWORD attr = FILE_ATTRIBUTE_NORMAL;

  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;

  hnd = CreateFileA(
    filename,
    access,
    0,
    &sa,
    OPEN_EXISTING,
    attr,
    NULL
  );

  if (hnd == INVALID_HANDLE_VALUE) {
    return -1;
  } else {
    *pxsocket = hnd;
    return 0;
  }
  
#else
  struct sockaddr_un addr;
  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd == -1) {
    return -1;
  }
  memset(&addr, 0, sizeof(struct sockaddr_un));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, filename, sizeof(addr.sun_path) - 1);

  int ret = connect(
    fd,
    (struct sockaddr *) &addr,
    sizeof(struct sockaddr_un)
  );

  if (ret == -1) {
    return -1;
  }

  *pxsocket = fd;
  return 0;
  
#endif
}

PROCESSX_STATIC ssize_t processx_socket_read(processx_socket_t *pxsocket,
                                             void *buf,
                                             size_t nbyte) {
#ifdef _WIN32
  DWORD got;
  BOOL ok = ReadFile(
    /* hFile =                */ *pxsocket,
    /* lpBuffer =             */ buf,
    /* nNumberOfBytesToRead = */ nbyte,
    /* lpNumberOfBytesRead =  */ &got,
    /* lpOverlapped =         */ NULL
  );
  if (!ok) {
    return -1;
  } else {
    return got;
  }

#else
  return read(*pxsocket, buf, nbyte);
#endif
}

PROCESSX_STATIC ssize_t processx_socket_write(processx_socket_t *pxsocket,
                                              void *buf,
                                              size_t nbyte) {
#ifdef _WIN32
  DWORD did;
  BOOL ok = WriteFile(
    /* hFile = */ *pxsocket,
    /* lpBuffer = */ buf,
    /* nNumberOfBytesToWrite = */ nbyte,
    /* lpNumberOfBytesWritten = */ &did,
    /* lpOverlapped = */ NULL
  );
  if (!ok) {
    return -1;
  } else {
    return did;
  }

#else
  return write(*pxsocket, buf, nbyte);
#endif
}

PROCESSX_STATIC int processx_socket_close(processx_socket_t *pxsocket) {
#ifdef _WIN32
  BOOL ok = CloseHandle(*pxsocket);
  if (!ok) {
    return -1;
  } else {
    return 0;
  }
#else
  return close(*pxsocket);
#endif
}
  
#ifdef __cplusplus
}
#endif

#endif
