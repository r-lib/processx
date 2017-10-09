
#ifndef PROCESSX_CONNECTION_H
#define PROCESSX_CONNECTION_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Riconv.h>

#ifdef _WIN32
#include <windows.h>
#endif

typedef struct processx_connection_s {
  int is_eof_;			/* the UTF8 buffer */
  int is_eof_raw_;		/* the raw file */

  void *iconv_ctx;

#ifdef _WIN32
  HANDLE handle;
  OVERLAPPED overlapped;
  BOOLEAN read_pending;
#else
  int fd;
#endif

  char* buffer;
  size_t buffer_allocated_size;
  size_t buffer_data_size;

  char *utf8;
  size_t utf8_allocated_size;
  size_t utf8_data_size;

} processx_connection_t;

/* API from R */

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

/* Start reading from async connection. This is needed for polling
   on Windows */
ssize_t processx_connection_start_read(processx_connection_t *con, int *result);

/* Do we have some data to read? */
int processx_connection_ready(processx_connection_t *con);

#endif
