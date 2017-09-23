
#include "processx-connection.h"

#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

/* Internal functions in this file */

static void processx__connection_alloc(processx_connection_t *ccon);
static void processx__connection_realloc(processx_connection_t *ccon);
static ssize_t processx__connection_read(processx_connection_t *ccon);
static ssize_t processx__find_newline(processx_connection_t *ccon,
				      size_t start);
static ssize_t processx__connection_read_until_newline(processx_connection_t
						       *ccon);
static void processx__connection_xfinalizer(SEXP con);
static ssize_t processx__connection_to_utf8(processx_connection_t *ccon);
static void processx__connection_find_utf_chars(processx_connection_t *ccon,
						size_t max, size_t *chars,
						size_t *bytes);

/* Api from R */

SEXP processx_connection_read_chars(SEXP con, SEXP nchars) {

  processx_connection_t *ccon = R_ExternalPtrAddr(con);
  SEXP result;
  int cnchars = asInteger(nchars);
  int should_read_more;
  size_t read_bytes;
  size_t utf8_chars, utf8_bytes;

  if (!ccon) error("Invalid connection object");
  if (ccon->fd < 0) error("Invalid (uninitialized?) connection object");

  should_read_more = ! ccon->is_eof_ && ccon->utf8_data_size == 0;
  if (should_read_more) read_bytes = processx__connection_read(ccon);

  if (ccon->utf8_data_size == 0 || cnchars == 0) {
    return ScalarString(mkCharCE("", CE_UTF8));
  }

  /* At at most cnchars characters from the UTF8 buffer */
  processx__connection_find_utf_chars(ccon, cnchars, &utf8_chars,
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
  ssize_t newline, eol = -1, lines_read = 0;
  size_t l;
  int add_eof = 0;
  if (cn < 0) cn = 1000;

  if (!ccon) error("Invalid connection object");
  if (ccon->fd < 0) error("Invalid (uninitialized?) connection object");

  /* Read until a newline character shows up, or there is nothing more
     to read (at least for now). */
  newline = processx__connection_read_until_newline(ccon);

  /* Count the number of lines we got. */
  while (newline != -1 && lines_read < cn) {
    lines_read ++;
    newline = processx__find_newline(ccon, /* start = */ newline + 1);
  }

  /* If there is no newline at the end of the file, we still add the
     last line. */
  if (ccon->is_eof_raw_ && ccon->utf8_data_size != 0 &&
      ccon->buffer_data_size == 0 &&
      ccon->utf8[ccon->utf8_data_size - 1] != '\n') {
    add_eof = 1;
  }

  result = PROTECT(allocVector(STRSXP, lines_read + add_eof));
  for (l = 0, newline = -1; l < lines_read; l++) {
    eol = processx__find_newline(ccon, newline + 1);
    SET_STRING_ELT(
      result, l,
      mkCharLenCE(ccon->utf8 + newline + 1, eol - newline - 1, CE_UTF8));
    newline = eol;
  }

  if (add_eof) {
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
  if (ccon->fd >= 0) close(ccon->fd);
  ccon->fd = -1;
  return R_NilValue;
}

/* Api from C -----------------------------------------------------------*/

SEXP processx_connection_new(processx_connection_t *con) {
  SEXP result, class;
  con->is_eof_  = 0;
  con->is_eof_raw_ = 0;

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

/* Can we read? We can read immediately (without an actual device read) if
 * 1. there is data in the UTF8 buffer, or
 * 2. there is data in the raw buffer, and we are at EOF, or
 * 3. there is data in the raw buffer, and we can convert it to UTF8.
 */

int processx__connection_ready(processx_connection_t *ccon) {
  if (!ccon) return 0;
  if (ccon->fd < 0) return 0;

  if (ccon->utf8_data_size > 0) return 1;
  if (ccon->buffer_data_size > 0 && ccon->is_eof_) return 1;
  if (ccon->buffer_data_size > 0) {
    processx__connection_to_utf8(ccon);
    if (ccon->utf8_data_size > 0) return 1;
    if (ccon->buffer_data_size > 0 && ccon->is_eof_) return 1;
  }

  return 0;
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
  bytes_read = read(ccon->fd, ccon->buffer + ccon->buffer_data_size, todo);

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

static void processx__connection_find_utf_chars(processx_connection_t *ccon,
						size_t max, size_t *chars,
						size_t *bytes) {

  char *ptr = ccon->utf8;
  char *end = ccon->utf8 + ccon->utf8_data_size;
  size_t length = ccon->utf8_data_size;
  *chars = *bytes = 0;

  while (max > 0 && ptr < end) {
    int clen, c = (unsigned char) *ptr;

    /* ASCII byte */
    if (c < 128) {
      (*chars) ++; (*bytes) ++; ptr++; max--; length--;
      continue;
    }

    /* Catch some errors */
    if (c <  0xc0) goto invalid;
    if (c >= 0xfe) goto invalid;

    clen = processx__utf8_length[c & 0x3f];
    if (length < clen) goto invalid;
    (*chars) ++; (*bytes) += clen; ptr += clen; max--; length -= clen;
  }

  return;

 invalid:
  error("Invalid UTF-8 string, internal error");
}
