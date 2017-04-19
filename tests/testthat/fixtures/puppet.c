
#include <windows.h>
#include <stdio.h>

#include "stdio-buffer.h"

void error(DWORD errorcode) {
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

  fprintf(stderr, "Error: %s\n", (char*) lpMsgBuf);
  exit(1);
}

int main() {

  BYTE *buffer;
  HANDLE read, write;
  STARTUPINFO si = { sizeof(si) };

  char readBuffer[10];
  DWORD bytes_read, bytes_written;
  BOOL ret;

  GetStartupInfo(&si);

  buffer = si.lpReserved2;
  write = CHILD_STDIO_HANDLE(buffer, 3);
  read = CHILD_STDIO_HANDLE(buffer, 4);

  ret = ReadFile(read, readBuffer, 10, &bytes_read,
		 /* lpOverlapped = */ 0);
  if (!ret) error(GetLastError());

  printf("Read %d bytes\n", (int) bytes_read);

  ret = WriteFile(write, readBuffer, bytes_read, &bytes_written,
		  /* lpOverlapped = */ 0);
  if (!ret) error(GetLastError());

  return 0;
}
