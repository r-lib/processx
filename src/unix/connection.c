
#include "../processx.h"

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>


processx_connection_t* processx__create_connection(
  int fd, const char *membername,
  SEXP private) {

  processx_connection_t *con;
  SEXP res;

  con = processx_c_connection_create(fd, PROCESSX_FILE_TYPE_ASYNCPIPE,
				     "", &res);

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
