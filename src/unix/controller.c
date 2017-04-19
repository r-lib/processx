
#include <unistd.h>

#include "processx-unix.h"

/* Only the read function is special */

size_t processx__control_read(void *target, size_t sz, size_t ni,
			      Rconnection con) {

  int num;
  int fd = con->status;

  if (fd < 0) error("Connection was already closed");
  if (sz != 1) error("Can only read bytes from processx connections");

  /* Already got EOF? */
  if (con->EOF_signalled) return 0;

  num = read(fd, target, ni);

  con->incomplete = 1;

  if (num < 0 && errno == EAGAIN) {
    num = 0;

  } else if (num < 0) {
    error("Cannot read from processx control pipe");

  } else if (num == 0) {
    con->incomplete = 0;
    con->EOF_signalled = 1;

  } else {
    /* proper read, nothing special to do */
  }

  return (size_t) num;
}

void processx__create_control_read(processx_handle_t *handle,
				   int fd, const char *membername,
				   SEXP private) {
  Rconnection con;
  SEXP res = PROTECT(R_new_custom_connection("processx_control", "r",
					     "textConnection", &con));

  con->incomplete = 1;
  con->EOF_signalled = 0;
  con->private = handle;
  con->status = fd;		/* slight abuse */
  con->canseek = 0;
  con->canwrite = 0;
  con->canread = 1;
  con->isopen = 1;
  con->blocking = 0;
  con->text = 0;
  con->UTF8out = 0;
  con->destroy = &processx__con_destroy;
  con->read = &processx__control_read;
  con->fgetc = &processx__con_fgetc;
  con->fgetc_internal = &processx__con_fgetc;

  defineVar(install(membername), res, private);
  UNPROTECT(1);
}

extern int R_ignore_SIGPIPE;

size_t processx__control_write(const void *ptr, size_t size, size_t nitems,
			       Rconnection con) {
  int fd = con->status;
  size_t ret;

  if (fd < 0) error("Connection was already closed");

  R_ignore_SIGPIPE = 1;
  ret = write(fd, ptr, size * nitems);
  R_ignore_SIGPIPE = 0;

  return ret;
}

void processx__create_control_write(processx_handle_t *handle,
				    int fd, const char *membername,
				    SEXP private) {
  Rconnection con;
  SEXP res = PROTECT(R_new_custom_connection("processx_control", "w",
					     "textConnection", &con));

  con->incomplete = 1;
  con->EOF_signalled = 0;
  con->private = handle;
  con->status = fd;		/* slight abuse */
  con->canseek = 0;
  con->canwrite = 1;
  con->canread = 0;
  con->isopen = 1;
  con->blocking = 0;
  con->text = 0;
  con->UTF8out = 0;
  con->destroy = &processx__con_destroy;
  con->write = &processx__control_write;

  defineVar(install(membername), res, private);
  UNPROTECT(1);
}

SEXP processx_poll_control(SEXP status, SEXP ms, SEXP conn_pipe) {

  int cms = INTEGER(ms)[0];
  processx_handle_t *handle = R_ExternalPtrAddr(status);
  struct pollfd fd;
  int ret;

  if (!handle) error("Internal processx error, handle already removed");

  fd.fd = handle->fd3;
  fd.events = POLLIN;
  fd.revents = 0;

  do {
    ret = poll(&fd, 1, cms);
  } while (ret == -1 && errno == EINTR);

  if (ret == -1) {
    error("Processx control poll error: %s", strerror(errno));
    return R_NilValue;

  } else if (ret == 0) {
    return ScalarInteger(PXTIMEOUT);

  } else {
    return ScalarInteger(processx__poll_decode(fd.revents));
  }
}
