
#include <Rinternals.h>
#include <stdlib.h>
#include <string.h>

#include "errors.h"

#ifdef LONG_VECTOR_SUPPORT
typedef R_xlen_t px_len_t;
#define PXS_MAX_LENGTH R_XLEN_T_MAX
#else
typedef size_t px_len_t;
#define PXS_MAX_LENGTH SIZE_MAX
#endif

struct pxs_buffer {
  px_len_t alloc_size;
  px_len_t size;
  unsigned char *data;
};

#define PXS_MINSIZE 8192 * 2

static void processx__resize_buffer(struct pxs_buffer *buf,
                                    px_len_t needed) {

  if (needed > PXS_MAX_LENGTH) R_THROW_ERROR("serialized object too big");

  if (needed < PXS_MINSIZE) {
    needed = PXS_MINSIZE;
  } else if (needed < 10 * 1024 * 1024) {
    needed = 2 * needed;
  } else if (needed < INT_MAX / 1.2 - 100) {
    needed = 1.2 * (double) needed;
  }

  unsigned char *tmp = realloc(buf->data, needed);
  if (tmp == NULL) {
    free(buf->data);
    buf->data = NULL;
    R_THROW_ERROR("cannot allocate buffer");
  }

  buf->data = tmp;
  buf->alloc_size = needed;
}

static void processx__serialize_outchar_mem(R_outpstream_t stream, int c) {
  struct pxs_buffer *buf = stream->data;
  if (buf->size >= buf->alloc_size) {
    processx__resize_buffer(buf, buf->size + 1);
  }
  buf->data[buf->size++] = (char) c;
}

static void processx__serialize_outbytes_mem(R_outpstream_t stream,
                                             void *newdata, int length) {
  struct pxs_buffer *buf = stream->data;
  px_len_t needed = buf->size + (px_len_t) length;
#ifndef LONG_VECTOR_SUPPORT
  /* There is a potential overflow here on 32-bit systems */
  if ((double) buf->size + length > (double) INT_MAX) {
    R_THROW_ERROR("serialized object too big");
  }
#endif
  if (needed > buf->alloc_size) processx__resize_buffer(buf, needed);
  memcpy(buf->data + buf->size, newdata, length);
  buf->size = needed;
}

static SEXP processx__serialize_close_mem(R_outpstream_t stream) {
  SEXP val;
  struct pxs_buffer *buf = stream->data;
  PROTECT(val = allocVector(RAWSXP, buf->size));
  memcpy(RAW(val), buf->data, buf->size);
  if (buf->data != NULL) free(buf->data);
  buf->data = NULL;
  UNPROTECT(1);
  return val;
}

SEXP processx_serialize_to_raw(SEXP x, SEXP version) {
  struct R_outpstream_st out = { 0 };
  R_pstream_format_t type = R_pstream_binary_format;
  SEXP (*hook)(SEXP, SEXP) = NULL; /* TODO: support hook */
  struct pxs_buffer buf = { 0, 0, NULL };

  R_InitOutPStream(
    &out, (R_pstream_data_t) &buf, type, asInteger(version),
    processx__serialize_outchar_mem, processx__serialize_outbytes_mem,
    hook, R_NilValue);

  R_Serialize(x, &out);

  return processx__serialize_close_mem(&out);
}

static int processx__serialize_inchar_mem(R_inpstream_t stream) {
  struct pxs_buffer *buf = stream->data;
  if (buf->size >= buf->alloc_size) R_THROW_ERROR("unserialize read error");
  return buf->data[buf->size++];
}

static void processx__serialize_inbytes_mem(R_inpstream_t stream,
                                            void *newdata, int length) {
  struct pxs_buffer *buf = stream->data;
  if (buf->size + (px_len_t) length > buf->alloc_size) {
    R_THROW_ERROR("unserialize read error");
  }
  memcpy(newdata, buf->data + buf->size, length);
  buf->size += length;
}

SEXP processx_unserialize_from_raw(SEXP sx) {
  struct R_inpstream_st in = { 0 };
  SEXP (*hook)(SEXP, SEXP) = NULL; /* TODO: support hook */
  px_len_t length = XLENGTH(sx);
  struct pxs_buffer buf = { length, 0, RAW(sx) };

  R_InitInPStream(
    &in, (R_pstream_data_t) &buf, R_pstream_any_format,
    processx__serialize_inchar_mem, processx__serialize_inbytes_mem,
    hook, R_NilValue);

  return R_Unserialize(&in);
}
