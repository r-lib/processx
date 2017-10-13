
#ifndef PROCESSX_CONNECTION_H
#define PROCESSX_CONNECTION_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Riconv.h>

#ifdef _WIN32
#include <windows.h>
#endif

/* --------------------------------------------------------------------- */
/* Data types                                                            */
/* --------------------------------------------------------------------- */

#ifdef _WIN32
typedef HANDLE processx_file_handle_t;
typedef struct {
  HANDLE handle;
  OVERLAPPED overlapped;
  BOOLEAN read_pending;
} processx_i_connection_t;
#else
typedef int processx_file_handle_t;
typedef int processx_i_connection_t;
#endif

typedef struct processx_connection_s {
  int is_eof_;			/* the UTF8 buffer */
  int is_eof_raw_;		/* the raw file */

  char *encoding;
  void *iconv_ctx;

  processx_i_connection_t handle;

  char* buffer;
  size_t buffer_allocated_size;
  size_t buffer_data_size;

  char *utf8;
  size_t utf8_allocated_size;
  size_t utf8_data_size;

} processx_connection_t;

typedef int (*processx_connection_poll_func_t)(
  void *object,
  int status,
  processx_file_handle_t **handle);

typedef struct processx_pollable_s {
  processx_connection_poll_func_t poll_func;
  void *object;
  int events;
} processx_pollable_t;

/* --------------------------------------------------------------------- */
/* API from R                                                            */
/* --------------------------------------------------------------------- */

/* Create connection from fd / HANDLE */
SEXP processx_connection_create(SEXP handle, SEXP encoding);

/* Read characters in a given encoding from the connection. */
SEXP processx_connection_read_chars(SEXP con, SEXP nchars);

/* Read lines of characters from the connection. */
SEXP processx_connection_read_lines(SEXP con, SEXP nlines);

/* Check if the connection has ended. */
SEXP processx_connection_is_eof(SEXP con);

/* Close the connection. */
SEXP processx_connection_close(SEXP con);

/* Poll connections and other pollable handles */
SEXP processx_connection_poll(SEXP pollables, SEXP timeout);

/* --------------------------------------------------------------------- */
/* API from C                                                            */
/* --------------------------------------------------------------------- */

/* Create connection object */
processx_connection_t *processx_c_connection_create(
  processx_file_handle_t os_handle,
  const char *encoding,
  SEXP *r_connection);

/* Read characters */
ssize_t processx_c_connection_read_chars(
  processx_connection_t *con,
  void *buffer,
  size_t nbyte);

/* Read lines of characters */
ssize_t processx_c_connection_read_line(
  processx_connection_t *ccon,
  char **linep,
  size_t *linecapp);

/* Check if the connection has ended */
int processx_c_connection_is_eof(
  processx_connection_t *con);

/* Close */
void processx_c_connection_close(
  processx_connection_t *con);

/* Poll connections and other pollable handles */
int processx_c_connection_poll(
  processx_pollable_t pollables[],
  size_t npollables, int timeout);

/* --------------------------------------------------------------------- */
/* Internals                                                             */
/* --------------------------------------------------------------------- */

#ifndef _WIN32
typedef unsigned long DWORD;
#endif

#define PROCESSX_ERROR(m,c) processx__error((m),(c),__FILE__,__LINE__)
void processx__error(const char *message, DWORD errorcode,
		     const char *file, int line);

#endif
