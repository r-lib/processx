
#include <windows.h>
#include <stdio.h>

#include "stdio-buffer.h"

void error(const char *msg, DWORD errorcode) {
  LPVOID lpMsgBuf;

  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    errorcode,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR) &lpMsgBuf,
    0, NULL );

  fprintf(stderr, "%s error: %s\n", msg, (char*) lpMsgBuf);
  exit(1);
}

int main() {

  BYTE *buffer;
  HANDLE read, write;
  STARTUPINFO si = { sizeof(si) };

  char readBuffer[1024], *pos = readBuffer;
  DWORD bytes_read, bytes_written;
  BOOL ret;
  OVERLAPPED ov = { 0 };

  GetStartupInfo(&si);

  buffer = si.lpReserved2;
  write = CHILD_STDIO_HANDLE(buffer, 3);
  read = CHILD_STDIO_HANDLE(buffer, 4);

  /* Nonblocking read, wait until there is data, and we
     also make sure that we got a whole line, closed by \n */
  readBuffer[0] = '\0';
  pos = readBuffer;
  while (! strchr(readBuffer, '\n') && pos - readBuffer < sizeof(readBuffer)) {
    ret = ReadFile(read, pos, sizeof(readBuffer) - (pos - readBuffer), &bytes_read, &ov);
    if (!ret) {
      DWORD err = GetLastError();
      if (err == ERROR_IO_PENDING) {
	WaitForSingleObject(ov.hEvent, 1000);
	GetOverlappedResult(read, &ov, &bytes_read, TRUE);
      } else {
	error("ReadFile", err);
      }
    }
    pos += bytes_read;
  }

  printf("Read %d bytes\n", pos - readBuffer);

  ret = WriteFile(write, readBuffer, pos - readBuffer, &bytes_written,
		  /* lpOverlapped = */ 0);
  if (!ret) error("WriteFile", GetLastError());

  return 0;
}
