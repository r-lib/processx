
#include "../processx.h"

HANDLE processx__connection_iocp = NULL;

HANDLE processx__get_default_iocp() {

  if (! processx__connection_iocp) {
    processx__connection_iocp = CreateIoCompletionPort(
    /* FileHandle = */                 INVALID_HANDLE_VALUE,
    /* ExistingCompletionPort = */     NULL,
    /* CompletionKey = */              0,
    /* NumberOfConcurrentThreads =  */ 0);

    if (! processx__connection_iocp) {
      PROCESSX_ERROR("cannot create default IOCP", GetLastError());
    }
  }

  return processx__connection_iocp;
}
