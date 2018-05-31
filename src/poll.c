
#include "processx.h"

SEXP processx_poll(SEXP statuses, SEXP conn, SEXP ms) {
  int cms = INTEGER(ms)[0];
  int i, j, num_total = LENGTH(statuses);
  processx_pollable_t *pollables;
  SEXP result;
  int num_conn = 0;
  int num_proc, num_poll;

  for (i = 0; i < num_total; i++) if (LOGICAL(conn)[i]) num_conn++;
  num_proc = num_total - num_conn;
  num_poll = num_conn + num_proc * 3;

  pollables = (processx_pollable_t*)
    R_alloc(num_poll, sizeof(processx_pollable_t));

  result = PROTECT(allocVector(VECSXP, num_total));
  for (i = 0, j = 0; i < num_total; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    if (LOGICAL(conn)[i]) {
      processx_connection_t *handle = R_ExternalPtrAddr(status);
      processx_c_pollable_from_connection(&pollables[j], handle);
      if (handle) handle->poll_idx = j;
      j++;
      SET_VECTOR_ELT(result, i, allocVector(INTSXP, 1));

    } else {
      SEXP process = VECTOR_ELT(status, 0);
      SEXP pollconn = VECTOR_ELT(status, 1);
      processx_handle_t *handle = R_ExternalPtrAddr(process);
      processx_connection_t *cpollconn = isNull(pollconn) ? 0 :
	R_ExternalPtrAddr(pollconn);

      processx_c_pollable_from_connection(&pollables[j], handle->pipes[1]);
      if (handle->pipes[1]) handle->pipes[1]->poll_idx = j;
      j++;
      processx_c_pollable_from_connection(&pollables[j], handle->pipes[2]);
      if (handle->pipes[2]) handle->pipes[2]->poll_idx = j;
      j++;

      processx_c_pollable_from_connection(&pollables[j], cpollconn);
      if (cpollconn) cpollconn->poll_idx = j;
      j++;

      SET_VECTOR_ELT(result, i, allocVector(INTSXP, 3));
    }
  }

  processx_c_connection_poll(pollables, num_poll, cms);

  for (i = 0, j = 0; i < num_total; i++) {
    if (LOGICAL(conn)[i]) {
      INTEGER(VECTOR_ELT(result, i))[0] = pollables[j++].event;
    } else {
      INTEGER(VECTOR_ELT(result, i))[0] = pollables[j++].event;
      INTEGER(VECTOR_ELT(result, i))[1] = pollables[j++].event;
      INTEGER(VECTOR_ELT(result, i))[2] = pollables[j++].event;
    }
  }

  UNPROTECT(1);
  return result;
}
