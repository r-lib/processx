
#ifdef _WIN32

#include <Rinternals.h>
#include "processx-win.h"

DWORD processx__poll_start_read(processx_pipe_handle_t *handle, int *result);

SEXP processx_poll(SEXP statuses, SEXP ms, SEXP outputs, SEXP errors) {
  int cms = INTEGER(ms)[0], timeleft = cms;
  int i, j, num_proc = LENGTH(statuses);
  int num_fds = 0;
  HANDLE *wait_handles;
  int *ptr;
  SEXP result;
  int has_buffered = 0;
  DWORD err, waitres;
  char *errmessage = "";

  /* Count the number of handles to listen on */
  for (i = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *px = R_ExternalPtrAddr(status);
    SEXP out = VECTOR_ELT(outputs, i);
    SEXP err = VECTOR_ELT(errors, i);
    if (!px) continue;
    num_fds += !isNull(out) && px->pipes[1] && px->pipes[1]->pipe &&
      px->pipes[1]->buffer;
    num_fds += !isNull(err) && px->pipes[2] && px->pipes[2]->pipe &&
      px->pipes[2]->buffer;
  }

  /* Allocate and pre-fill result, we also check for buffered data */
  result = PROTECT(allocVector(VECSXP, num_proc));
  for (i = 0; i < num_proc; i++) {
    SEXP out = VECTOR_ELT(outputs, i);
    SEXP err = VECTOR_ELT(errors, i);
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *px = R_ExternalPtrAddr(status);
    SET_VECTOR_ELT(result, i, allocVector(INTSXP, 2));
    if (isNull(out)) {
      INTEGER(VECTOR_ELT(result, i))[0] = PXNOPIPE;
    } else if (! px || ! px->pipes[1] || ! px->pipes[1]->pipe || !px->pipes[1]->buffer) {
      INTEGER(VECTOR_ELT(result, i))[0] = PXCLOSED;
    } else {
      if (px->pipes[1]->buffer_end > px->pipes[1]->buffer) {
	INTEGER(VECTOR_ELT(result, i))[0] = PXREADY;
	has_buffered = 1;
      } else {
	INTEGER(VECTOR_ELT(result, i))[0] = PXSILENT;
      }
    }
    if (isNull(err)) {
      INTEGER(VECTOR_ELT(result, i))[1] = PXNOPIPE;
    } else if (! px || ! px->pipes[2] || ! px->pipes[2]->pipe || !px->pipes[2]->buffer) {
      INTEGER(VECTOR_ELT(result, i))[1] = PXCLOSED;
    } else {
      if (px->pipes[2]->buffer_end > px->pipes[2]->buffer) {
	INTEGER(VECTOR_ELT(result, i))[1] = PXREADY;
	has_buffered = 1;
      } else {
	INTEGER(VECTOR_ELT(result, i))[1] = PXSILENT;
      }
    }
  }

  if (num_fds == 0 || has_buffered) {
    UNPROTECT(1);
    return result;
  }

  /* For each open pipe that does not have IO pending, start an async read */
  for (i = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *px = R_ExternalPtrAddr(status);
    int *ii = INTEGER(VECTOR_ELT(result, i));
    if (ii[0] == PXSILENT && ! px->pipes[1]->read_pending) {
      err = processx__poll_start_read(px->pipes[1], ii);
      if (err) { errmessage = "start async poll read (stdout)"; goto error; }
      if (ii[0] == PXREADY) has_buffered = 1;
    }
    if (ii[1] == PXSILENT && ! px->pipes[2]->read_pending) {
      err = processx__poll_start_read(px->pipes[2], ii + 1);
      if (err) { errmessage = "start async poll read (stderr)"; goto error; }
      if (ii[1] == PXREADY) has_buffered = 1;
    }
  }

  if (has_buffered) {
    UNPROTECT(1);
    return result;
  }

  /* If we are still alive, then we have some pending reads. Wait on them. */
  wait_handles = (HANDLE*) R_alloc(num_fds, sizeof(HANDLE));
  ptr = (int*) R_alloc(num_fds, sizeof(int));
  for (i = 0, j = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *px= R_ExternalPtrAddr(status);
    int *ii = INTEGER(VECTOR_ELT(result, i));
    if (ii[0] == PXSILENT) {
      wait_handles[j] = px->pipes[1]->overlapped.hEvent;
      ptr[j++] = 2 * i;
    }
    if (ii[1] == PXSILENT) {
      wait_handles[j] = px->pipes[2]->overlapped.hEvent;
      ptr[j++] = 2 * i + 1;
    }
  }

  waitres = WAIT_TIMEOUT;
  while (cms < 0 || timeleft > PROCESSX_INTERRUPT_INTERVAL) {
    waitres = WaitForMultipleObjects(
      num_fds,
      wait_handles,
      /* bWaitAll = */ FALSE,
      PROCESSX_INTERRUPT_INTERVAL);

    if (waitres != WAIT_TIMEOUT) break;

    R_CheckUserInterrupt();
    timeleft -= PROCESSX_INTERRUPT_INTERVAL;
  }

  /* Maybe some time left from the timeout */
  if (waitres == WAIT_TIMEOUT && timeleft >= 0) {
    waitres = WaitForMultipleObjects(
      num_fds,
      wait_handles,
      /* bWaitAll = */ FALSE,
      timeleft);
  }

  if (waitres == WAIT_FAILED) {
    err = GetLastError();
    errmessage = "waiting in poll";
    goto error;

  } else if (waitres == WAIT_TIMEOUT) {
    for (i = 0; i < num_proc; i++) {
      int *ii = INTEGER(VECTOR_ELT(result, i));
      if (ii[0] == PXSILENT) ii[0] = PXTIMEOUT;
      if (ii[1] == PXSILENT) ii[1] = PXTIMEOUT;
    }

  } else {
    int ready = waitres - WAIT_OBJECT_0;
    int *ii = INTEGER(VECTOR_ELT(result, ptr[ready] / 2));
    ii[ptr[ready] % 2] = PXREADY;
  }

  UNPROTECT(1);
  return result;

 error:
  PROCESSX_ERROR(errmessage, err);
  return R_NilValue;		/* never called */
}

#endif
