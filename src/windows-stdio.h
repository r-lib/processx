
#ifndef R_PROCESSX_WINDOWS_STDIO_H
#define R_PROCESSX_WINDOWS_STDIO_H

#include <windows.h>
#include "utils.h"

int uv_utf8_to_utf16_alloc(const char* s, WCHAR** ws_ptr);

int processx__stdio_create(const char *std_out, const char *std_err,
			   BYTE** buffer_ptr);
WORD processx__stdio_size(BYTE* buffer);
HANDLE processx__stdio_handle(BYTE* buffer, int fd);


#endif
