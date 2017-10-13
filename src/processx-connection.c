
#include "processx-connection.h"

#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef _WIN32
#include <sys/uio.h>
#endif

#include "processx.h"

/* Internal functions in this file */

static void processx__connection_find_chars(processx_connection_t *ccon,
					    ssize_t maxchars,
					    ssize_t maxbytes,
					    size_t *chars,
					    size_t *bytes);

static void processx__connection_find_lines(processx_connection_t *ccon,
					    ssize_t maxlines,
					    size_t *lines,
					    int *eof);

static void processx__connection_alloc(processx_connection_t *ccon);
static void processx__connection_realloc(processx_connection_t *ccon);
static ssize_t processx__connection_read(processx_connection_t *ccon);
static ssize_t processx__find_newline(processx_connection_t *ccon,
				      size_t start);
static ssize_t processx__connection_read_until_newline(processx_connection_t
						       *ccon);
static void processx__connection_xfinalizer(SEXP con);
static ssize_t processx__connection_to_utf8(processx_connection_t *ccon);
static void processx__connection_find_utf8_chars(processx_connection_t *ccon,
						 ssize_t maxchars,
						 ssize_t maxbytes,
						 size_t *chars,
						 size_t *bytes);

#ifdef _WIN32
#define PROCESSX_CHECK_VALID_CONN(x) do {				   \
    if (!x) error("Invalid connection object");				   \
    if (!(x)->handle.handle) error("Invalid (uninitialized?) connection object"); \
  } while (0)
#else
#define PROCESSX_CHECK_VALID_CONN(x) do {				\
    if (!x) error("Invalid connection object");				\
    if ((x)->handle < 0) error("Invalid (uninitialized?) connection object"); \
  } while (0)
#endif

/* --------------------------------------------------------------------- */
/* API from R                                                            */
/* --------------------------------------------------------------------- */

SEXP processx_connection_create(SEXP handle, SEXP encoding) {
  processx_file_handle_t *os_handle = R_ExternalPtrAddr(handle);
  processx_connection_t *con;
  const char *c_encoding = CHAR(STRING_ELT(encoding, 0));
  SEXP result;

  if (!os_handle) error("Cannot create connection, invalid handle");

  con = processx_c_connection_create(*os_handle, c_encoding, &result);
  return result;
}

SEXP processx_connection_read_chars(SEXP con, SEXP nchars) {

  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  SEXP result;
  int cnchars = asInteger(nchars);
  size_t utf8_chars, utf8_bytes;

  processx__connection_find_chars(ccon, cnchars, -1, &utf8_chars,
				  &utf8_bytes);

  result = PROTECT(ScalarString(mkCharLenCE(ccon->utf8, utf8_bytes,
					    CE_UTF8)));
  ccon->utf8_data_size -= utf8_bytes;
  memmove(ccon->utf8, ccon->utf8 + utf8_bytes, ccon->utf8_data_size);

  UNPROTECT(1);
  return result;
}

SEXP processx_connection_read_lines(SEXP con, SEXP nlines) {

  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  SEXP result;
  int cn = asInteger(nlines);
  ssize_t newline, eol = -1;
  size_t lines_read = 0, l;
  int eof = 0;
  int slashr;

  processx__connection_find_lines(ccon, cn, &lines_read, &eof);

  result = PROTECT(allocVector(STRSXP, lines_read + eof));
  for (l = 0, newline = -1; l < lines_read; l++) {
    eol = processx__find_newline(ccon, newline + 1);
    slashr = ccon->utf8[eol - 1] == '\r';
    SET_STRING_ELT(
      result, l,
      mkCharLenCE(ccon->utf8 + newline + 1, eol - newline - 1 - slashr, CE_UTF8));
    newline = eol;
  }

  if (eof) {
    eol = ccon->utf8_data_size - 1;
    SET_STRING_ELT(
      result, l,
      mkCharLenCE(ccon->utf8 + newline + 1, eol - newline, CE_UTF8));
  }

  if (eol >= 0) {
    ccon->utf8_data_size -= eol + 1;
    memmove(ccon->utf8, ccon->utf8 + eol + 1, ccon->utf8_data_size);
  }

  UNPROTECT(1);
  return result;
}

SEXP processx_connection_is_eof(SEXP con) {
  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  if (!ccon) error("Invalid connection object");
  return ScalarLogical(ccon->is_eof_);
}

SEXP processx_connection_close(SEXP con) {
  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  if (!ccon) error("Invalid connection object");
  processx_c_connection_close(ccon);
  return R_NilValue;
}

/* Poll connections and other pollable handles */
SEXP processx_connection_poll(SEXP pollables, SEXP timeout) {
  /* TODO */
}

/* Api from C -----------------------------------------------------------*/

processx_connection_t *processx_c_connection_create(
  processx_file_handle_t os_handle,
  const char *encoding,
  SEXP *r_connection) {

  processx_connection_t *con;
  SEXP result, class;

  con = malloc(sizeof(processx_connection_t));
  if (!con) error("out of memory");

#ifdef _WIN32
  con->handle.handle = os_handle;
  memset(&con->handle.overlapped, 0, sizeof(OVERLAPPED));
  con->handle.read_pending = FALSE;
  con->handle.overlapped.hEvent = CreateEvent(
    /* lpEventAttributes = */ NULL,
    /* bManualReset = */      FALSE,
    /* bInitialState = */     FALSE,
    /* lpName = */            NULL);

  if (con->handle.overlapped.hEvent == NULL) {
    free(con);
    PROCESSX_ERROR("Cannot create connection event", GetLastError());
  }
#else
  con->handle = os_handle;
#endif

  if (r_connection) {
    result = PROTECT(R_MakeExternalPtr(con, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(result, processx__connection_xfinalizer, 1);
    class = PROTECT(ScalarString(mkChar("processx_connection")));
    setAttrib(result, R_ClassSymbol, class);
    *r_connection = result;
  }

  con->is_eof_  = 0;
  con->is_eof_raw_ = 0;
  con->iconv_ctx = 0;

  con->buffer = 0;
  con->buffer_allocated_size = 0;
  con->buffer_data_size = 0;

  con->utf8 = 0;
  con->utf8_allocated_size = 0;
  con->utf8_data_size = 0;

  if (r_connection) UNPROTECT(2);
  return con;
}

/* Read characters */
ssize_t processx_c_connection_read_chars(processx_connection_t *ccon,
					 void *buffer,
					 size_t nbyte) {
  size_t utf8_chars, utf8_bytes;

  if (nbyte < 4) {
    error("Buffer sie must be at least 4 bytes, to allow multibyte "
	  "characters");
  }

  processx__connection_find_chars(ccon, -1, nbyte, &utf8_chars, &utf8_bytes);

  memcpy(buffer, ccon->utf8, utf8_bytes);
  ccon->utf8_data_size -= utf8_bytes;
  memmove(ccon->utf8, ccon->utf8 + utf8_bytes, ccon->utf8_data_size);

  return utf8_bytes;
}

/**
 * Read a single line, ending with \n
 *
 * The trailing \n character is not copied to the buffer.
 *
 * @param ccon Connection.
 * @param linep Must point to a buffer pointer. If must not be NULL. If
 *   the buffer pointer is NULL, it will be allocated. If it is not NULL,
 *   it might be reallocated using `realloc`, as needed.
 * @param linecapp Initial size of the buffer. It will be updated if the
 *   buffer is newly allocated or reallocated.
 * @return Number of characters read, not including the \n character.
 *   It returns -1 on EOF. If the connection is not at EOF yet, but there
 *   is nothing to read currently, it returns 0. If 0 is returned, `linep`
 *   and `linecapp` are not touched.
 *
 */
ssize_t processx_c_connection_read_line(processx_connection_t *ccon,
					char **linep, size_t *linecapp) {

  int eof = 0;
  ssize_t newline;

  if (!linep) error("linep cannot be a null pointer");
  if (!linecapp) error("linecapp cannot be a null pointer");

  if (ccon->is_eof_) return -1;

  /* Read until a newline character shows up, or there is nothing more
     to read (at least for now). */
  newline = processx__connection_read_until_newline(ccon);

  /* If there is no newline at the end of the file, we still add the
     last line. */
  if (ccon->is_eof_raw_ && ccon->utf8_data_size != 0 &&
      ccon->buffer_data_size == 0 &&
      ccon->utf8[ccon->utf8_data_size - 1] != '\n') {
    eof = 1;
  }

  /* We cannot serve a line currently. Maybe later. */
  if (newline == -1 && ! eof) return 0;

  /* Newline will contain the end of the line now, even if EOF */
  if (newline == -1) newline = ccon->utf8_data_size;
  if (ccon->utf8[newline - 1] == '\r') newline--;

  if (! *linep) {
    *linep = malloc(newline + 1);
    *linecapp = newline + 1;
  } else if (*linecapp < newline + 1) {
    char *tmp = realloc(*linep, newline + 1);
    if (!tmp) error("out of memory");
    *linep = tmp;
    *linecapp = newline + 1;
  }

  memcpy(*linep, ccon->utf8, newline);
  (*linep)[newline] = '\0';

  if (!eof) {
    ccon->utf8_data_size -= (newline + 1);
    memmove(ccon->utf8, ccon->utf8 + newline + 1, ccon->utf8_data_size);
  } else {
    ccon->utf8_data_size = 0;
  }

  return newline;
}

/* Check if the connection has ended */
int processx_c_connection_is_eof(processx_connection_t *ccon) {
  return ccon->is_eof_;
}

/* Close */
void processx_c_connection_close(processx_connection_t *ccon) {
#ifdef _WIN32
  if (ccon->handle.handle) CloseHandle(ccon->handle.handle);
  ccon->handle.handle = 0;
  if (ccon->handle.overlapped.hEvent) {
    CloseHandle(ccon->handle.overlapped.hEvent);
  }
  ccon->handle.overlapped.hEvent = 0;
#else
  if (ccon->handle >= 0) close(ccon->handle);
  ccon->handle = -1;
#endif
}

/* Poll connections and other pollable handles */
int processx_c_connection_poll(processx_pollable_t pollables[],
			       size_t npollables, int timeout);

/* --------------------------------------------------------------------- */
/* Internals                                                             */
/* --------------------------------------------------------------------- */

/**
 * Work out how many UTF-8 characters we can read
 *
 * It might try to read more data, but it does not modify the buffer
 * otherwise.
 *
 * @param ccon Connection.
 * @param maxchars Maximum number of characters to find.
 * @param maxbytes Maximum number of bytes to check while searching.
 * @param chars Number of characters found is stored here.
 * @param bytes Number of bytes the `chars` characters span.
 *
 */

static void processx__connection_find_chars(processx_connection_t *ccon,
					    ssize_t maxchars,
					    ssize_t maxbytes,
					    size_t *chars,
					    size_t *bytes) {

  int should_read_more;

  PROCESSX_CHECK_VALID_CONN(ccon);

  should_read_more = ! ccon->is_eof_ && ccon->utf8_data_size == 0;
  if (should_read_more) processx__connection_read(ccon);

  if (ccon->utf8_data_size == 0 || maxchars == 0) { *bytes = 0; return; }

  /* At at most cnchars characters from the UTF8 buffer */
  processx__connection_find_utf8_chars(ccon, maxchars, maxbytes, chars,
				       bytes);
}

/**
 * Find one or more lines in the buffer
 *
 * Since the buffer is UTF-8 encoded, `\n` is assumed as end-of-line
 * character.
 *
 * @param ccon Connection.
 * @param maxlines Maximum number of lines to find.
 * @param lines Number of lines found is stored here.
 * @param eof If the end of the file is reached, and there is no `\n`
 *   at the end of the file, this is set to 1.
 *
 */

static void processx__connection_find_lines(processx_connection_t *ccon,
					    ssize_t maxlines,
					    size_t *lines,
					    int *eof ) {

  ssize_t newline;

  *eof = 0;

  if (maxlines < 0) maxlines = 1000;

  PROCESSX_CHECK_VALID_CONN(ccon);

  /* Read until a newline character shows up, or there is nothing more
     to read (at least for now). */
  newline = processx__connection_read_until_newline(ccon);

  /* Count the number of lines we got. */
  while (newline != -1 && *lines < maxlines) {
    (*lines) ++;
    newline = processx__find_newline(ccon, /* start = */ newline + 1);
  }

  /* If there is no newline at the end of the file, we still add the
     last line. */
  if (ccon->is_eof_raw_ && ccon->utf8_data_size != 0 &&
      ccon->buffer_data_size == 0 &&
      ccon->utf8[ccon->utf8_data_size - 1] != '\n') {
    *eof = 1;
  }

}

#ifdef _WIN32

/* TODO: remove this, have proper polling */

ssize_t processx_connection_start_read(processx_connection_t *ccon, int *result) {

  DWORD bytes_read;
  BOOLEAN res;
  size_t todo;

  if (result) *result = PXSILENT;

  if (!ccon->handle.handle) {
    if (result) *result = PXCLOSED;
    return 0;
  }

  if (ccon->handle.read_pending) return 0;

  if (!ccon->buffer) processx__connection_alloc(ccon);

  todo = ccon->buffer_allocated_size - ccon->buffer_data_size;

  ccon->handle.overlapped.Offset = 0;
  ccon->handle.overlapped.OffsetHigh = 0;
  res = ReadFile(
    /* hfile = */                ccon->handle.handle,
    /* lpBuffer = */             ccon->buffer + ccon->buffer_data_size,
    /* nNumberOfBytesToRead = */ todo,
    /* lpNumberOfBytesRead = */  &bytes_read,
    /* lpOverlapped = */         &ccon->handle.overlapped);

  if (!res) {
    DWORD err = GetLastError();
    if (err == ERROR_BROKEN_PIPE || err == ERROR_HANDLE_EOF) {
      ccon->is_eof_raw_ = 1;
      if (ccon->utf8_data_size == 0 && ccon->buffer_data_size == 0) {
	ccon->is_eof_ = 1;
	if (result) *result = PXREADY;
      }
    } else if (err == ERROR_IO_PENDING) {
      ccon->handle.read_pending = TRUE;
    } else {
      ccon->handle.read_pending = FALSE;
      PROCESSX_ERROR("reading from connection", err);
    }
  } else {
    /* Returned synchronously. */
    ccon->handle.read_pending = FALSE;
    if (result) *result = PXREADY;
    ccon->buffer_data_size += bytes_read;
    return (ssize_t) bytes_read;
  }

  return 0;
}

#endif

/* Can we read? We can read immediately (without an actual device read) if
 * 1. there is data in the UTF8 buffer, or
 * 2. there is data in the raw buffer, and we are at EOF, or
 * 3. there is data in the raw buffer, and we can convert it to UTF8.
 */

/* TODO: remove this */

int processx_connection_ready(processx_connection_t *ccon) {
  if (!ccon) return 0;

#ifdef _WIN32
  if (!ccon->handle->handle) return 0;
#else
  if (ccon->handle < 0) return 0;
#endif

  if (ccon->utf8_data_size > 0) return 1;
  if (ccon->buffer_data_size > 0 && ccon->is_eof_) return 1;
  if (ccon->buffer_data_size > 0) {
    processx__connection_to_utf8(ccon);
    if (ccon->utf8_data_size > 0) return 1;
    if (ccon->buffer_data_size > 0 && ccon->is_eof_) return 1;
  }

  return 0;
}

static void processx__connection_xfinalizer(SEXP con) {
  processx_connection_t *ccon = R_ExternalPtrAddr(con);

  processx_c_connection_close(ccon);

  if (!ccon) return;

  if (ccon->iconv_ctx) Riconv_close(ccon->iconv_ctx);

  if (ccon->buffer) free(ccon->buffer);
  if (ccon->utf8) free(ccon->utf8);

  free(ccon);
}

static ssize_t processx__find_newline(processx_connection_t *ccon,
				     size_t start) {

  if (ccon->utf8_data_size == 0) return -1;
  const char *ret = ccon->utf8 + start;
  const char *end = ccon->utf8 + ccon->utf8_data_size;

  while (ret < end && *ret != '\n') ret++;

  if (ret < end) return ret - ccon->utf8; else return -1;
}

static ssize_t processx__connection_read_until_newline
  (processx_connection_t *ccon) {

  char *ptr, *end;

  /* Make sure we try to have something, unless EOF */
  if (ccon->utf8_data_size == 0) processx__connection_read(ccon);
  if (ccon->utf8_data_size == 0) return -1;

  /* We have sg in the utf8 at this point */

  ptr = ccon->utf8;
  end = ccon->utf8 + ccon->utf8_data_size;
  while (1) {
    ssize_t new_bytes;
    while (ptr < end && *ptr != '\n') ptr++;

    /* Have we found a newline? */
    if (ptr < end) return ptr - ccon->utf8;

    /* No newline, but EOF? */
    if (ccon->is_eof_) return -1;

    /* Maybe we can read more, but might need a bigger utf8.
     * The 8 bytes is definitely more than what we need for a UTF8
     * character, and this makes sure that we don't stop just because
     * no more UTF8 characters fit in the UTF8 buffer. */
    if (ccon->utf8_data_size >= ccon->utf8_allocated_size - 8) {
      size_t ptrnum = ptr - ccon->utf8;
      size_t endnum = end - ccon->utf8;
      processx__connection_realloc(ccon);
      ptr = ccon->utf8 + ptrnum;
      end = ccon->utf8 + endnum;
    }
    new_bytes = processx__connection_read(ccon);

    /* If we cannot read now, then we give up */
    if (new_bytes == 0) return -1;
  }

  /* Never reached */
  return -1;
}

/* Allocate buffer for reading */

static void processx__connection_alloc(processx_connection_t *ccon) {
  ccon->buffer = malloc(64 * 1024);
  if (!ccon->buffer) error("Cannot allocate memory for processx buffer");
  ccon->buffer_allocated_size = 64 * 1024;
  ccon->buffer_data_size = 0;

  ccon->utf8 = malloc(64 * 1024);
  if (!ccon->utf8) {
    free(ccon->buffer);
    error("Cannot allocate memory for processx buffer");
  }
  ccon->utf8_allocated_size = 64 * 1024;
  ccon->utf8_data_size = 0;
}

/* We only really need to re-alloc the UTF8 buffer, because the
   other buffer is transient, even if there are no newline characters. */

static void processx__connection_realloc(processx_connection_t *ccon) {
  void *nb = realloc(ccon->utf8, ccon->utf8_allocated_size * 1.2);
  if (!nb) error("Cannot allocate memory for processx line");
  ccon->utf8 = nb;
  ccon->utf8_allocated_size = ccon->utf8_allocated_size * 1.2;
}

/* Read as much as we can. This is the only function that explicitly
   works with the raw buffer. It is also the only function that actually
   reads from the data source.

   When this is called, the UTF8 buffer is probably empty, but the raw
   buffer might not be. */

#ifdef _WIN32

static ssize_t processx__connection_read(processx_connection_t *ccon) {
  DWORD todo, bytes_read = 0;
  BOOLEAN result;

  /* Nothing to read, nothing to convert to UTF8 */
  if (ccon->is_eof_raw_ && ccon->buffer_data_size == 0) {
    if (ccon->utf8_data_size == 0) ccon->is_eof_ = 1;
    return 0;
  }

  if (!ccon->buffer) processx__connection_alloc(ccon);

  /* If cannot read anything more, then try to convert to UTF8 */
  todo = ccon->buffer_allocated_size - ccon->buffer_data_size;
  if (todo == 0) return processx__connection_to_utf8(ccon);

  /* Otherwise we read. If there is no read pending, we start one. */
  processx_connection_start_read(ccon, /* result = */ 0);

  /* A read might be pending at this point. See if it has finished. */
  if (ccon->handle.read_pending) {
    result = GetOverlappedResult(
      /* hFile = */                      &ccon->handle.handle,
      /* lpOverlapped = */               &ccon->handle.overlapped,
      /* lpNumberOfBytesTransferred = */ &bytes_read,
      /* bWait = */                      FALSE);

    if (!result) {
      DWORD err = GetLastError();
      if (err == ERROR_BROKEN_PIPE || err == ERROR_HANDLE_EOF) {
	ccon->handle.read_pending = FALSE;
	ccon->is_eof_raw_ = 1;
	if (ccon->utf8_data_size == 0 && ccon->buffer_data_size == 0) {
	  ccon->is_eof_ = 1;
	}
	bytes_read = 0;

      } else if (err == ERROR_IO_INCOMPLETE) {

      } else {
	ccon->handle.read_pending = FALSE;
	PROCESSX_ERROR("getting overlapped result in connection read", err);
	return 0;			/* never called */
      }

    } else {
      ccon->handle.read_pending = FALSE;
    }
  }

  ccon->buffer_data_size += bytes_read;

  /* If there is anything to convert to UTF8, try converting */
  if (ccon->buffer_data_size > 0) {
    bytes_read = processx__connection_to_utf8(ccon);
  }

  return bytes_read;
}

#else

static ssize_t processx__connection_read(processx_connection_t *ccon) {
  ssize_t todo, bytes_read;

  /* Nothing to read, nothing to convert to UTF8 */
  if (ccon->is_eof_raw_ && ccon->buffer_data_size == 0) {
    if (ccon->utf8_data_size == 0) ccon->is_eof_ = 1;
    return 0;
  }

  if (!ccon->buffer) processx__connection_alloc(ccon);

  /* If cannot read anything more, then try to convert to UTF8 */
  todo = ccon->buffer_allocated_size - ccon->buffer_data_size;
  if (todo == 0) return processx__connection_to_utf8(ccon);

  /* Otherwise we read */
  bytes_read = read(ccon->handle, ccon->buffer + ccon->buffer_data_size, todo);

  if (bytes_read == 0) {
    /* EOF */
    ccon->is_eof_raw_ = 1;
    if (ccon->utf8_data_size == 0 && ccon->buffer_data_size == 0) {
      ccon->is_eof_ = 1;
    }

  } else if (bytes_read == -1 && errno == EAGAIN) {
    /* There is still data to read, potentially */
    bytes_read = 0;

  } else if (bytes_read == -1) {
    /* Proper error  */
    error("Cannot read from processx connection: %s", strerror(errno));
  }

  ccon->buffer_data_size += bytes_read;

  /* If there is anything to convert to UTF8, try converting */
  if (ccon->buffer_data_size > 0) {
    bytes_read = processx__connection_to_utf8(ccon);
  }

  return bytes_read;
}
#endif

static ssize_t processx__connection_to_utf8(processx_connection_t *ccon) {

  const char *inbuf, *inbufold;
  char *outbuf, *outbufold;
  size_t inbytesleft = ccon->buffer_data_size;
  size_t outbytesleft = ccon->utf8_allocated_size - ccon->utf8_data_size;
  size_t r, indone = 0, outdone = 0;
  int moved = 0;

  inbuf = inbufold = ccon->buffer;
  outbuf = outbufold = ccon->utf8 + ccon->utf8_data_size;

  /* If we this is the first time we are here. */
  if (! ccon->iconv_ctx) ccon->iconv_ctx = Riconv_open("UTF-8", "");

  /* If nothing to do, or no space to do more, just return */
  if (inbytesleft == 0 || outbytesleft == 0) return 0;

  while (!moved) {
    r = Riconv(ccon->iconv_ctx, &inbuf, &inbytesleft, &outbuf,
	       &outbytesleft);
    moved = 1;

    if (r == (size_t) -1) {
      /* Error */
      if (errno == E2BIG) {
	/* Output buffer is full, that's fine, we'll try later.
	   Just use what we have done so far. */

      } else if (errno == EILSEQ) {
	/* Invalid characters in encoding, *inbuf points to the beginning
	   of the invalid sequence. We can just try to remove this, and
	   convert again? */
	inbuf++; inbytesleft--;
	if (inbytesleft > 0) moved = 0;

      } else if (errno == EINVAL) {
	/* Does not end with a complete multi-byte character */
	/* This is fine, we'll handle it later, unless we are at the end */
	if (ccon->is_eof_raw_) {
	  warning("Invalid multi-byte character at end of stream ignored");
	  inbuf += inbytesleft; inbytesleft = 0;
	}
      }
    }
  }

  /* We converted 'r' bytes, update the buffer structure accordingly */
  indone = inbuf - inbufold;
  outdone = outbuf - outbufold;
  if (outdone > 0 || indone > 0) {
    ccon->buffer_data_size -= indone;
    memmove(ccon->buffer, ccon->buffer + indone, ccon->buffer_data_size);
    ccon->utf8_data_size += outdone;
  }

  return outdone;
}

/* Try to get at max 'max' UTF8 characters from the buffer. Return the
 * number of characters found, and also the corresponding number of
 * bytes. */

/* Number of additional bytes */
static const unsigned char processx__utf8_length[] = {
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
  4,4,4,4,4,4,4,4,5,5,5,5,6,6,6,6 };

static void processx__connection_find_utf8_chars(processx_connection_t *ccon,
						 ssize_t maxchars,
						 ssize_t maxbytes,
						 size_t *chars,
						 size_t *bytes) {

  char *ptr = ccon->utf8;
  char *end = ccon->utf8 + ccon->utf8_data_size;
  size_t length = ccon->utf8_data_size;
  *chars = *bytes = 0;

  while (maxchars != 0 && maxbytes != 0 && ptr < end) {
    int clen, c = (unsigned char) *ptr;

    /* ASCII byte */
    if (c < 128) {
      (*chars) ++; (*bytes) ++; ptr++; length--;
      if (maxchars > 0) maxchars--;
      if (maxbytes > 0) maxbytes--;
      continue;
    }

    /* Catch some errors */
    if (c <  0xc0) goto invalid;
    if (c >= 0xfe) goto invalid;

    clen = processx__utf8_length[c & 0x3f];
    if (length < clen) goto invalid;
    if (maxbytes > 0 && clen > maxbytes) break;
    (*chars) ++; (*bytes) += clen; ptr += clen; length -= clen;
    if (maxchars > 0) maxchars--;
    if (maxbytes > 0) maxbytes -= clen;
  }

  return;

 invalid:
  error("Invalid UTF-8 string, internal error");
}

#undef PROCESSX_CHECK_VALID_CONN
