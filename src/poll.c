
#include "processx.h"

/* Create a pollable from a process object
 *
 * @param pollable Pointer to the object to fill.
 * @param process The input process object.
 * @param which Which stream to poll. Possible values:
 *   * 0: stdin (not implemented yet)
 *   * 1: stdout
 *   * 2: stderr
 *   * 3: control connection (not implemented yet)
 */

int processx_c_pollable_from_process(
  processx_pollable_t *pollable,
  processx_handle_t *process,
  int which) {

  switch (which) {
  case 0:
    error("Polling `stdin` is not implemented yet");
    break;
  case 1:
    return processx_c_pollable_from_connection(pollable, process->pipes[1]);
  case 2:
    return processx_c_pollable_from_connection(pollable, process->pipes[2]);
  case 3:
    error("Polling the control connection is not implemented yet");
    break;
  default:
    error("Invalid connection requested for polling");
    break;
  }

  return 0;
}

SEXP processx_poll(SEXP statuses, SEXP ms) {
  int cms = INTEGER(ms)[0];
  int i, num_proc = LENGTH(statuses);
  processx_pollable_t *pollables;
  SEXP result;

  pollables = (processx_pollable_t*)
    R_alloc(num_proc * 2, sizeof(processx_pollable_t));

  result = PROTECT(allocVector(VECSXP, num_proc));
  for (i = 0; i < num_proc; i++) {
    SEXP status = VECTOR_ELT(statuses, i);
    processx_handle_t *handle = R_ExternalPtrAddr(status);
    processx_c_pollable_from_connection(&pollables[i*2], handle->pipes[1]);
    processx_c_pollable_from_connection(&pollables[i*2+1], handle->pipes[2]);
    SET_VECTOR_ELT(result, i, allocVector(INTSXP, 2));
  }

  processx_c_connection_poll(pollables, num_proc * 2, cms);

  for (i = 0; i < num_proc; i++) {
    INTEGER(VECTOR_ELT(result, i))[0] = pollables[i*2].event;
    INTEGER(VECTOR_ELT(result, i))[1] = pollables[i*2+1].event;
  }

  UNPROTECT(1);
  return result;
}
