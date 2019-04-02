
#include "../processx.h"

HANDLE processx__iocp_thread = NULL;
HANDLE processx__thread_start = NULL;
HANDLE processx__thread_done = NULL;
int processx__thread_result = PROCESSX__THREAD_SUCCESS;
int processx__thread_cmd = 0;
processx_connection_t *processx__thread_conn = 0;
ssize_t processx__thread_bytes_read = 0;
processx_pollable_t *processx__thread_pollables = 0;
size_t processx__thread_npollables = 0;
int processx__thread_timeout = 0;
int processx__thread_hasdata = 0;

DWORD processx__thread_callback(void *data) {
  while (1) {
    WaitForSingleObject(processx__thread_start, INFINITE);

    processx__thread_result = PROCESSX__THREAD_SUCCESS;

    switch (processx__thread_cmd) {
    case PROCESSX__THREAD_IDLE:
      break;
    case PROCESSX__THREAD_READ:
      processx__thread_bytes_read =
	processx__connection_read_thr(processx__thread_conn);
      break;
    case PROCESSX__THREAD_POLL:
      processx__thread_hasdata =
	processx_c_connection_poll_thr(processx__thread_pollables,
				       processx__thread_npollables,
				       processx__thread_timeout);
      break;
    default:
      processx__thread_result = PROCESSX__THREAD_ERROR;
      break;
    }

    processx__thread_cmd = PROCESSX__THREAD_IDLE;
    SetEvent(processx__thread_done);
  }
  return 0;
}

int processx__start_thread() {
  if (processx__iocp_thread != NULL) return 0;

  DWORD threadid;

  processx__thread_start = CreateEventA(NULL, FALSE, FALSE, NULL);
  processx__thread_done  = CreateEventA(NULL, FALSE, FALSE, NULL);

  if (processx__thread_start == NULL || processx__thread_done == NULL) {
    if (processx__thread_start) CloseHandle(processx__thread_start);
    if (processx__thread_done ) CloseHandle(processx__thread_done);
    processx__thread_start = processx__thread_done = NULL;
    PROCESSX_ERROR("Cannot create I/O events", GetLastError());
  }

  processx__iocp_thread = CreateThread(
    /* lpThreadAttributes = */ NULL,
    /* dwStackSize = */        0,
    /* lpStartAddress = */
      (LPTHREAD_START_ROUTINE) processx__thread_callback,
    /* lpParameter = */        0,
    /* dwCreationFlags = */    0,
    /* lpThreadId = */         &threadid);

  if (processx__iocp_thread == NULL) {
    CloseHandle(processx__thread_start);
    CloseHandle(processx__thread_done);
    processx__thread_start = processx__thread_done = NULL;
    PROCESSX_ERROR("Cannot start I/O thread", GetLastError());
  }

  /* Wait for thread to be ready */
  SetEvent(processx__thread_start);
  WaitForSingleObject(processx__thread_done, INFINITE);

  return 0;
}
