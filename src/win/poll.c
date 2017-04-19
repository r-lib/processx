
#include <Rinternals.h>
#include "processx-win.h"

void processx__error(DWORD errorcode);
DWORD processx__poll_start_read(processx_pipe_handle_t *handle, int *result);

int processx__poll_internal(processx_pipe_handle_t **handles, int num_handles, int ms,
			    int *result) {

  int i, j;
  int has_buffered = 0, num_active = 0;
  HANDLE *wait_handles;
  int *ptr;
  DWORD err, waitres;

  /* Check buffered data */
  for (i = 0; i < num_handles; i++) {
    if (!handles[i] || !handles[i]->buffer) {
      result[i] = PXCLOSED;
    } else {
      num_active ++;
      if (handles[i]->buffer_end > handles[i]->buffer) {
	result[i] = PXREADY;
	has_buffered = 1;
      } else {
	result[i] = PXSILENT;
      }
    }
  }

  if (num_active == 0 || has_buffered) return 0;

  /* For each open pipe that does not have IO pending, start an async read */
  for (i = 0; i < num_handles; i++) {
    if (result[i] == PXSILENT && ! handles[i]->read_pending) {
      err = processx__poll_start_read(handles[i], result + i);
      if (err) goto error;
      if (result[i] == PXREADY) has_buffered = 1;
    }
  }

  if (has_buffered) return 0;

  /* If we are still alive, then we have some pending reads. Wait on them. */
  wait_handles = (HANDLE*) R_alloc(num_active, sizeof(HANDLE));
  ptr = (int*) R_alloc(num_active, sizeof(int));
  for (i = 0, j = 0; i < num_handles; i++) {
    if (result[i] == PXSILENT) {
      wait_handles[j] = handles[i]->overlapped.hEvent;
      ptr[j++] = i;
    }
  }

  waitres = WaitForMultipleObjects(
    num_active,
    wait_handles,
    /* bWaitAll = */ FALSE,
    ms >= 0 ? ms : INFINITE);

  if (waitres == WAIT_FAILED) {
    err = GetLastError();
    goto error;

  } else if (waitres == WAIT_TIMEOUT) {
    for (i = 0; i < num_handles; i++) {
      if (result[i] == PXSILENT) result[i] = PXTIMEOUT;
    }

  } else {
    int ready = waitres - WAIT_OBJECT_0;
    result[ptr[ready]] = PXREADY;
  }

  return 0;

 error:
  processx__error(err);
  return 1;			/* never called */
}

SEXP processx_poll(SEXP statuses, SEXP ms, SEXP outputs, SEXP errors) {
  int cms = INTEGER(ms)[0];
  int i, j, num_proc = LENGTH(statuses);
  int num_fds = 0;
  HANDLE *wait_handles;
  int *ptr;
  SEXP result;
  int has_buffered = 0;
  DWORD err, waitres;

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
      if (err) goto error;
      if (ii[0] == PXREADY) has_buffered = 1;
    }
    if (ii[1] == PXSILENT && ! px->pipes[2]->read_pending) {
      err = processx__poll_start_read(px->pipes[2], ii + 1);
      if (err) goto error;
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

  waitres = WaitForMultipleObjects(
    num_fds,
    wait_handles,
    /* bWaitAll = */ FALSE,
    cms >= 0 ? cms : INFINITE);

  if (waitres == WAIT_FAILED) {
    err = GetLastError();
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
  processx__error(err);
  return R_NilValue;		/* never called */
}

SEXP processx_poll_control(SEXP status, SEXP ms, SEXP conn_pipe) {

  int cms = INTEGER(ms)[0];
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  processx_pipe_handle_t *pipe = handle->pipes[3];
  int result;

  if (isNull(conn_pipe) || !pipe || !pipe->buffer) {
    error("No control conncetion, or it was closed");
  }

  processx__poll_internal(&pipe, 1, cms, &result);

  return ScalarInteger(result);
}
