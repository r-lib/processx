
#include "../processx.h"

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>


processx_connection_t* processx__create_connection(
  int fd, const char *membername,
  SEXP private) {

  processx_connection_t *con;
  SEXP res;

  con = processx_c_connection_create(fd, "", &res);

  defineVar(install(membername), res, private);

  return con;
}

void processx__create_connections(processx_handle_t *handle, SEXP private) {
  handle->pipes[0] = handle->pipes[1] = handle->pipes[2] = 0;

  if (handle->fd1 >= 0) {
    handle->pipes[1] = processx__create_connection(handle->fd1,
						   "stdout_pipe", private);
  }

  if (handle->fd2 >= 0) {
    handle->pipes[2] = processx__create_connection(handle->fd2,
						   "stderr_pipe", private);
  }
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
