
#define USE_RINTERNALS

#include "../processx.h"

#include <Windows.h>
#include <Memoryapi.h>

#include <R_ext/Rallocators.h>

SEXP processx__mmap_pack(SEXP filename, SEXP data) {
  int i, n = LENGTH(data);
  static int sexpsize = sizeof(SEXPTYPE);
  static int xlensize = sizeof(R_xlen_t);
  static int lglsize = sizeof(LOGICAL(ScalarLogical(0))[0]);
  static int intsize = sizeof(INTEGER(ScalarInteger(0))[0]);
  static int realsize = sizeof(REAL(ScalarReal(0))[0]);
  static int sexprecsize = sizeof(SEXPREC_ALIGN);
  static int allocatorsize = sizeof(R_allocator_t);
  int elementsize = sexpsize + xlensize + allocatorsize + sexprecsize;
  int fullsize = sizeof(int) + elementsize * n;
  Rbyte *map_orig, *map;
  SECURITY_ATTRIBUTES attr;

  /* Calculate the size we need */
  for (i = 0; i < n; i++) {
    SEXP elt = VECTOR_ELT(data, i);
    SEXPTYPE type = TYPEOF(elt);
    R_xlen_t len = LENGTH(elt);
    int eltsize;
    switch (type) {
    case LGLSXP:
      eltsize = lglsize;
      break;
    case INTSXP:
      eltsize = intsize;
      break;
    case REALSXP:
      eltsize = realsize;
      break;
    case RAWSXP:
      eltsize = 1;
      break;
    default:
      error("Unsupported type in mmap packing");
    }
    fullsize += len * eltsize;
  }

  memset(&attr, 0, sizeof attr);
  attr.bInheritHandle = TRUE;

  HANDLE fd = CreateFileMappingA(
    /* hFile =                   */ INVALID_HANDLE_VALUE,
    /* lpFileMappingAttributes = */ &attr,                  /* TODO */
    /* flProtect =               */ PAGE_READWRITE,
    /* dwMaximumSizeHigh =       */ 0,                     /* TODO */
    /* dwMaximumSizeLow =        */ fullsize,
    /* lpName =                  */ NULL);

  /* TODO: actual error message */
  if (fd == NULL) {
    error("Failed to create shared memory mapping: %d",
	  GetLastError());
  }

  map = map_orig = MapViewOfFile(
    /* hFileMappingObject   = */ fd,
    /* dwDesiredAccess      = */ FILE_MAP_READ | FILE_MAP_WRITE, 
    /* dwFileOffsetHigh     = */ 0,
    /* dwFileOffsetLow      = */ 0,
    /* dwNumberOfBytesToMap = */ fullsize);

  /* TODO: actual error message */
  if (map == NULL) {
    error("Failed to create shared memory view: %d",
	  GetLastError());
  }

  /* Need to copy the elements in place */
  /* number of elements first */
  memcpy(map, &n, sizeof(int));
  map += sizeof(int);

  /* then the map of objects */
  for (i = 0; i < n; i++) {
    SEXP elt = VECTOR_ELT(data, i);
    R_xlen_t len = LENGTH(elt);
    SEXPTYPE type = TYPEOF(elt);
    memcpy(map, &type, sexpsize);
    map += sexpsize;
    memcpy(map, &len, xlensize);
    map += xlensize;
  }

  /* then the objects themselves */
  for (i = 0; i < n; i++) {
    SEXP elt = VECTOR_ELT(data, i);
    SEXPTYPE type = TYPEOF(elt);
    R_xlen_t len = LENGTH(elt);
    int eltsize;
    Rbyte *src;
    switch (type) {
    case LGLSXP:
      eltsize = lglsize;
      src = (Rbyte*) LOGICAL(elt);
      break;
    case INTSXP:
      eltsize = intsize;
      src = (Rbyte*) INTEGER(elt);
      break;
    case REALSXP:
      eltsize = realsize;
      src = (Rbyte*) REAL(elt);
      break;
    case RAWSXP:
      eltsize = 1;
      src = (Rbyte*) RAW(elt);
      break;
    default:
      error("Unsupported type in mmap packing");
    }
    map += sexprecsize + allocatorsize;
    memcpy(map, src, eltsize * len);
    map += eltsize * len;
  }

  /* TODO: CloseHandle? */

  SEXP ret = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(ret, 0, R_MakeExternalPtr(fd, R_NilValue, R_NilValue));
  SET_VECTOR_ELT(ret, 1, ScalarInteger(fullsize));

  UNPROTECT(1);
  return ret;
}

void *processx__alloc(R_allocator_t *allocator, size_t size) {
  return allocator->data;
}

void processx__free(R_allocator_t *allocator, void *data) {
  /* TODO: munmap eventually, when all is freed */
}

SEXP processx__mmap_unpack(SEXP fd, SEXP size) {
  SEXP ret = R_NilValue;
  static int sexpsize = sizeof(SEXPTYPE);
  static int xlensize = sizeof(R_xlen_t);
  static int lglsize = sizeof(LOGICAL(ScalarLogical(0))[0]);
  static int intsize = sizeof(INTEGER(ScalarInteger(0))[0]);
  static int realsize = sizeof(REAL(ScalarReal(0))[0]);
  static int sexprecsize = sizeof(SEXPREC_ALIGN);
  static int allocatorsize = sizeof(R_allocator_t);
  int i, n;
  Rbyte *map, *map_orig;

  HANDLE c_fd = R_ExternalPtrAddr(fd);

  map = map_orig = MapViewOfFile(
    /* hFileMappingObject   = */ c_fd,
    /* dwDesiredAccess      = */ FILE_MAP_READ | FILE_MAP_WRITE, 
    /* dwFileOffsetHigh     = */ 0,
    /* dwFileOffsetLow      = */ 0,
    /* dwNumberOfBytesToMap = */ 0);

  /* TODO: actual error message */
  if (map == NULL) {
    error("Failed to create shared memory view: %d",
	  GetLastError());
  }
  
  memcpy(&n, map, sizeof(int));
  map += sizeof(int);
  ret = PROTECT(allocVector(VECSXP, n));
  Rbyte *data = map + n * (sexpsize + xlensize);

  struct R_allocator allocator =
    { processx__alloc, processx__free, NULL, NULL };

  for (i = 0; i < n; i++) {
    SEXPTYPE type;
    R_xlen_t len;
    int eltsize;
    memcpy(&type, map, sexpsize);
    map += sexpsize;
    memcpy(&len, map, xlensize);
    map += xlensize;

    switch (type) {
    case LGLSXP:
      eltsize = lglsize;
      break;
    case INTSXP:
      eltsize = intsize;
      break;
    case REALSXP:
      eltsize = realsize;
      break;
    case RAWSXP:
      eltsize = 1;
      break;
    default:
      error("Unsupported type in mmap unpacking");
    }

    allocator.data = data;
    SET_VECTOR_ELT(ret, i, allocVector3(type, len, &allocator));
    data += sexprecsize + allocatorsize + len * eltsize;
  }

  UNPROTECT(1);
  return ret;
}
