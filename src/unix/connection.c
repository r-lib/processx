
#include "processx-unix.h"

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>


processx_conn_handle_t* processx__create_connection(
  processx_handle_t *handle,
  int fd, const char *membername,
  SEXP private) {

  processx_conn_handle_t *conn_handle;
  processx_connection_t *con;
  SEXP res;

  conn_handle = (processx_conn_handle_t*)
    malloc(sizeof(processx_conn_handle_t));
  if (!conn_handle) error("out of memory");

  con = malloc(sizeof(processx_connection_t));
  if (!con) { free(conn_handle); error("out of memory"); }

  res = PROTECT(processx_connection_new(con));
  con->fd = fd;

  defineVar(install(membername), res, private);

  conn_handle->process = handle;
  conn_handle->conn = con;

  UNPROTECT(1);
  return conn_handle;
}

void processx__create_connections(processx_handle_t *handle, SEXP private) {

  if (handle->fd1 >= 0) {
    handle->std_out = processx__create_connection(handle, handle->fd1,
						 "stdout_pipe", private);
  }

  if (handle->fd2 >= 0) {
    handle->std_err = processx__create_connection(handle, handle->fd2,
						 "stderr_pipe", private);
  }
}
