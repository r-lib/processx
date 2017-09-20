
#include "processx-unix.h"

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

size_t processx__connection_read(processx_connection_t *con, void *buf,
				 size_t toread) {

  ssize_t num = read(con->fd, buf, toread);

  if (num < 0 && errno == EAGAIN) {
    /* Nothing to read from non-blocking connection */
    return 0;

  } else if (num < 0) {
    error("Cannot read from connection: %s", strerror(errno));

  } else if (num == 0) {
    con->is_eof_ = 1;
    return 0;

  } else {
    return (size_t) num;
  }
}

void processx__connection_close(processx_connection_t *con) {
  close(con->fd);
}

int processx__connection_is_eof(processx_connection_t *con) {
  return con->is_eof_;
}

void processx__connection_finalizer(processx_connection_t *con) {
  /* Try to close silently */
  close(con->fd);
}

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
