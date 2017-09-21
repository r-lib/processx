
#include "processx-connection.h"

#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

/* Internal functions in this file */

static void processx__connection_alloc(processx_connection_t *ccon);
static int processx__connection_has_valid_chars(processx_connection_t *ccon);
static ssize_t processx__connection_read(processx_connection_t *ccon);
static ssize_t processx__find_newline(processx_connection_t *ccon,
				      size_t start);
static ssize_t processx__connection_read_until_newline(processx_connection_t
						       *ccon);
static void processx__connection_xfinalizer(SEXP con);
static ssize_t processx__connection_to_utf8(processx_connection_t *ccon);

/* Api from R */

SEXP processx_connection_read_bin(SEXP con, SEXP bytes) {
  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  size_t cbytes = asInteger(bytes);
  ssize_t bytes_got;
  SEXP result;

  if (!ccon) error("Invalid connection object");
  if (ccon->fd < 0) error("Invalid (uninitialized?) connection object");

  /* Do we need to read at all? */
  if (ccon->utf8_data_size == 0) processx__connection_read(ccon);

  /* How much do have we got? */
  bytes_got = cbytes < ccon->utf8_data_size ? cbytes : ccon->utf8_data_size;

  /* OK, we have sg in the utf8 buf, copy it to the result */
  result = PROTECT(allocVector(RAWSXP, bytes_got));
  if (bytes_got > 0) {
    memcpy(RAW(result), ccon->utf8, bytes_got);
    ccon->utf8_data_size -= bytes_got;
    memmove(ccon->utf8, ccon->utf8 + bytes_got, ccon->utf8_data_size);
  }

  UNPROTECT(1);
  return result;
}

SEXP processx_connection_read_chars(SEXP con, SEXP nchars) {

  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  SEXP result;
  int cn = asInteger(nchars);
  int has_bytes;
  int has_valid_chars;
  int should_read_more;
  size_t read_bytes;

  if (!ccon) error("Invalid connection object");
  if (ccon->fd < 0) error("Invalid (uninitialized?) connection object");

  has_bytes = ccon->utf8_data_size;
  has_valid_chars = processx__connection_has_valid_chars(ccon);
  should_read_more = ! ccon->is_eof_ && ! has_valid_chars;

  if (should_read_more) {
    read_bytes = processx__connection_read(ccon);
    if (read_bytes > 0) {
      /* If there is sg new, then we try again */
      has_valid_chars = processx__connection_has_valid_chars(ccon);
    }
  }

  if (!has_valid_chars || cn == 0) return ScalarString(mkChar(""));

  /* TODO: encoding, etc. */
  if (ccon->utf8_data_size < cn) cn = ccon->utf8_data_size;
  result = PROTECT(ScalarString(mkCharLen(ccon->utf8, cn)));
  ccon->utf8_data_size -= cn;
  memmove(ccon->utf8, ccon->utf8 + cn, ccon->utf8_data_size);

  UNPROTECT(1);
  return result;
}

SEXP processx_connection_read_lines(SEXP con, SEXP nlines) {

  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  SEXP result;
  int cn = asInteger(nlines);
  ssize_t newline, eol = -1, lines_read = 0;
  size_t l;
  int add_eof = 0;
  if (cn < 0) cn = 1000;

  if (!ccon) error("Invalid connection object");
  if (ccon->fd < 0) error("Invalid (uninitialized?) connection object");

  newline = processx__connection_read_until_newline(ccon);

  while (newline != -1 && lines_read < cn) {
    lines_read ++;
    newline = processx__find_newline(ccon, /* start = */ newline + 1);
  }

  /* If there is no newline at the end of the file, we still add the
     last line. */
  if (ccon->is_eof_ && ccon->utf8_data_size != 0 &&
      ccon->utf8[ccon->utf8_data_size - 1] != '\n') {
    add_eof = 1;
  }

  result = PROTECT(allocVector(STRSXP, lines_read + add_eof));
  for (l = 0, newline = -1; l < lines_read; l++) {
    eol = processx__find_newline(ccon, newline + 1);
    SET_STRING_ELT(
      result, l,
      mkCharLen(ccon->utf8 + newline + 1, eol - newline - 1));
    newline = eol;
  }

  if (add_eof) {
    eol = ccon->utf8_data_size - 1;
    SET_STRING_ELT(
      result, l,
      mkCharLen(ccon->utf8 + newline + 1, eol - newline));
  }

  if (eol >= 0) {
    ccon->utf8_data_size -= eol + 1;
    memmove(ccon->utf8, ccon->utf8 + eol + 1, eol + 1);
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
  if (ccon->fd >= 0) close(ccon->fd);
  ccon->fd = -1;
  return R_NilValue;
}

/* Api from C -----------------------------------------------------------*/

SEXP processx_connection_new(processx_connection_t *con) {
  SEXP result, class;
  con->is_eof_  = 0;

  con->iconv_ctx = 0;
  con->fd = -1;

  con->buffer = 0;
  con->buffer_allocated_size = 0;
  con->buffer_data_size = 0;

  con->utf8 = 0;
  con->utf8_allocated_size = 0;
  con->utf8_data_size = 0;

  result = PROTECT(R_MakeExternalPtr(con, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(result, processx__connection_xfinalizer, 1);
  class = PROTECT(ScalarString(mkChar("processx_connection")));
  setAttrib(result, R_ClassSymbol, class);

  UNPROTECT(2);
  return result;
}

/* Internals ------------------------------------------------------------ */


static void processx__connection_xfinalizer(SEXP con) {
  processx_connection_t *ccon = R_ExternalPtrAddr(con);

  if (!ccon) return;

  if (ccon->iconv_ctx) Riconv_close(ccon->iconv_ctx);

  if (ccon->buffer) free(ccon->buffer);
  if (ccon->utf8) free(ccon->utf8);

  free(ccon);
}

static int processx__connection_has_valid_chars(processx_connection_t *ccon) {
  return ccon->utf8_data_size > 0;
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
  if (ccon->is_eof_) return -1;
  if (ccon->utf8_data_size == 0) processx__connection_read(ccon);
  if (ccon->utf8_data_size == 0) return -1;

  /* We have sg in the utf8 at this point */

  ptr = ccon->utf8;
  end = ccon->utf8 + ccon->utf8_data_size + 1;
  while (1) {
    ssize_t new_bytes;
    while (ptr < end && *ptr != '\n') ptr++;

    /* Have we found a newline? */
    if (ptr < end) return ptr - ccon->utf8;

    /* No newline, but EOF? */
    if (ccon->is_eof_) return -1;

    /* Maybe we can read more, but might need a bigger utf8 */
    if (ccon->utf8_data_size == ccon->utf8_allocated_size) {
      size_t ptrnum = ptr - ccon->utf8;
      size_t endnum = end - ccon->utf8;
      void *nb = realloc(ccon->utf8, ccon->utf8_allocated_size * 1.2);
      if (!nb) error("Cannot allocate memory for processx line");
      ccon->utf8 = nb;
      ccon->utf8_allocated_size = ccon->utf8_allocated_size * 1.2;
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

/* Read as much as we can. This is the only function that explicitly
   works with the raw buffer. It is also the only function that actually
   reads from the data source.

   When this is called, the UTF8 buffer is probably empty, but the raw
   buffer might not be. */

static ssize_t processx__connection_read(processx_connection_t *ccon) {
  ssize_t todo, bytes_read;

  if (ccon->is_eof_ && ccon->buffer_data_size == 0) return 0;

  if (!ccon->buffer) processx__connection_alloc(ccon);

  /* If cannot read anything more, then try to convert to UTF8 */
  todo = ccon->buffer_allocated_size - ccon->buffer_data_size;
  if (todo == 0) return processx__connection_to_utf8(ccon);

  /* Otherwise we read */
  bytes_read = read(ccon->fd, ccon->buffer + ccon->buffer_data_size, todo);

  if (bytes_read == 0) {
    /* EOF */
    ccon->is_eof_ = 1;
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

static ssize_t processx__connection_to_utf8(processx_connection_t *ccon) {

  const char *inbuf, *inbufold;
  char *outbuf, *outbufold;
  size_t inbytesleft = ccon->buffer_data_size;
  size_t outbytesleft = ccon->utf8_allocated_size - ccon->utf8_data_size;
  size_t r, indone = 0, outdone = 0;

  inbuf = inbufold = ccon->buffer;
  outbuf = outbufold = ccon->utf8 + ccon->utf8_data_size;

  /* If we this is the first time we are here.
     TODO: we could also use a single instance. */
  if (! ccon->iconv_ctx) ccon->iconv_ctx = Riconv_open("UTF-8", "");

  /* If nothing to do, or no space to do more, just return */
  if (inbytesleft == 0 || outbytesleft == 0) return 0;

  r = Riconv(ccon->iconv_ctx, &inbuf, &inbytesleft, &outbuf, &outbytesleft);

  if (r == (size_t) -1) {
    /* Error */
    if (errno == E2BIG) {
      /* Output buffer is full, that's fine, we try later */

    } else if (errno == EILSEQ) {
      /* Invalid characters in encoding */
      /* TODO: how to handle this? */

    } else if (errno == EINVAL) {
      /* Does not end with a complete multi-byte character */
      /* This is fine, we'll handle it later. */
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
