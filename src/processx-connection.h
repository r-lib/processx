
#ifndef PROCESSX_CONNECTION_H
#define PROCESSX_CONNECTION_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Riconv.h>

typedef struct processx_connection_s {
  int is_eof_;

  void *iconv_ctx;
  int fd;			/* This is for simplicity */

  char* buffer;
  size_t buffer_allocated_size;
  size_t buffer_data_size;

} processx_connection_t;

/* API from R */

/* Read a binary block from the connection */
SEXP processx_connection_read_bin(SEXP con, SEXP bytes);

/* Read characters in a given encoding from the connection. */
SEXP processx_connection_read_chars(SEXP con, SEXP nchars);

/* Read lines of characters from the connection. */
SEXP processx_connection_read_lines(SEXP con, SEXP nlines);

/* Check if the connection has ended. */
SEXP processx_connection_is_eof(SEXP con);

/* Close the connection. */
SEXP processx_connection_close(SEXP con);

/* API from C */

/* Create connection object */
SEXP processx_connection_new(processx_connection_t *con);

#endif
