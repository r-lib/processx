
#ifndef _WIN32

#include <Rinternals.h>

#include <poll.h>
#include <errno.h>

#include "../processx.h"
#include "processx-unix.h"

int processx__poll_decode(short code) {
  if (code & POLLNVAL) return PXCLOSED;
  if (code & POLLIN || code & POLLHUP) return PXREADY;
  return 0;
}

SEXP processx_poll_io(SEXP status, SEXP ms, SEXP stdout_pipe,
		      SEXP stderr_pipe) {
  int cms = INTEGER(ms)[0];
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  struct pollfd fds[2];
  int idx = 0, num = 0, ret;
  SEXP result;
  int ptr1 = -1, ptr2 = -1;

  if (!handle) { error("Internal processx error, handle already removed"); }

  if (handle->fd1 >= 0) {
    fds[idx].fd = handle->fd1;
    fds[idx].events = POLLIN;
    fds[idx].revents = 0;
    ptr1 = idx;
    idx++;
  }
  if (handle->fd2 >= 0) {
    fds[idx].fd = handle->fd2;
    fds[idx].events = POLLIN;
    fds[idx].revents = 0;
    ptr2 = idx;
  }

  result = PROTECT(allocVector(INTSXP, 2));
  if (isNull(stdout_pipe)) {
    INTEGER(result)[0] = PXNOPIPE;
  } else if (handle->fd1 < 0) {
    INTEGER(result)[0] = PXCLOSED;
  } else {
    num++;
    INTEGER(result)[0] = PXSILENT;
  }
  if (isNull(stderr_pipe)) {
    INTEGER(result)[1] = PXNOPIPE;
  } else if (handle->fd2 < 0) {
    INTEGER(result)[1] = PXCLOSED;
  } else {
    num++;
    INTEGER(result)[1] = PXSILENT;
  }

  /* Nothing to poll? */
  if (num == 0) {
    UNPROTECT(1);
    return result;
  }

  /* Interruptible poll */
  ret = processx__interruptible_poll(fds, num, cms);

  if (ret == -1) {
    error("Processx poll error: %s", strerror(errno));

  } else if (ret == 0) {
    if (ptr1 >= 0) INTEGER(result)[0] = PXTIMEOUT;
    if (ptr2 >= 0) INTEGER(result)[1] = PXTIMEOUT;

  } else {
    if (ptr1 >= 0 && fds[ptr1].revents) {
      INTEGER(result)[0] = processx__poll_decode(fds[ptr1].revents);
    }
    if (ptr2 >= 0 && fds[ptr2].revents) {
      INTEGER(result)[1] = processx__poll_decode(fds[ptr2].revents);
    }
  }

  UNPROTECT(1);
  return result;
}

SEXP processx_poll(SEXP statuses, SEXP ms, SEXP outputs, SEXP errors) {
  int cms = INTEGER(ms)[0];
  int i, j, num_proc = LENGTH(statuses);
  int num_fds = 0;
  struct pollfd *fds;
  int *ptr;
  SEXP result;
  int ret;

  /* Count the number of FDs to listen on */
  for (i = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *handle = R_ExternalPtrAddr(status);
    if (!handle) continue;
    num_fds += (handle->fd1 >= 0);
    num_fds += (handle->fd2 >= 0);
  }

  /* Create list of FDs */
  fds = (struct pollfd*) R_alloc(num_fds, sizeof(struct pollfd));
  ptr = (int*) R_alloc(num_fds, sizeof(int));
  for (i = 0, j = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *handle = R_ExternalPtrAddr(status);
    if (!handle) continue;
    if (handle->fd1 >= 0) {
      fds[j].fd = handle->fd1;
      fds[j].events = POLLIN;
      fds[j].revents = 0;
      ptr[j++] = 2 * i;		/* even is stdout */
    }
    if (handle->fd2 >= 0) {
      fds[j].fd = handle->fd2;
      fds[j].events = POLLIN;
      fds[j].revents = 0;
      ptr[j++] = 2 * i + 1;	/* odd is stderr */
    }
  }

  /* Allocate and pre-fill result */
  result = PROTECT(allocVector(VECSXP, num_proc));
  for (i = 0; i < num_proc; i++) {
    SEXP out = VECTOR_ELT(outputs, i);
    SEXP err = VECTOR_ELT(errors, i);
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *handle = R_ExternalPtrAddr(status);
    SET_VECTOR_ELT(result, i, allocVector(INTSXP, 2));
    if (isNull(out)) {
      INTEGER(VECTOR_ELT(result, i))[0] = PXNOPIPE;
    } else if (!handle || handle->fd1 < 0) {
      INTEGER(VECTOR_ELT(result, i))[0] = PXCLOSED;
    } else {
      INTEGER(VECTOR_ELT(result, i))[0] = PXSILENT;
    }
    if (isNull(err)) {
      INTEGER(VECTOR_ELT(result, i))[1] = PXNOPIPE;
    } else if (!handle || handle->fd2 < 0) {
      INTEGER(VECTOR_ELT(result, i))[1] = PXCLOSED;
    } else {
      INTEGER(VECTOR_ELT(result, i))[1] = PXSILENT;
    }
  }

  /* Poll, if there is anything to poll */
  if (num_fds == 0) {
    UNPROTECT(1);
    return result;
  }

  /* Interruptible poll */
  ret = processx__interruptible_poll(fds, num_fds, cms);

  /* Create result object */
  if (ret == -1) {
    error("Processx poll error: %s", strerror(errno));

  } else if (ret == 0) {
    for (i = 0; i < num_proc; i++) {
      int *ii = INTEGER(VECTOR_ELT(result, i));
      if (ii[0] == PXSILENT) ii[0] = PXTIMEOUT;
      if (ii[1] == PXSILENT) ii[1] = PXTIMEOUT;
    }

  } else {
    for (j = 0; j < num_fds; j++) {
      if (fds[j].revents) {
	int *ii = INTEGER(VECTOR_ELT(result, ptr[j] / 2));
	ii[ptr[j] % 2] = processx__poll_decode(fds[j].revents);
      }
    }
  }

  UNPROTECT(1);
  return result;
}

#endif
