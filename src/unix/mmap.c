
#define USE_RINTERNALS

#include "../processx.h"
#include "../errors.h"

#include <sys/mman.h>
#include <unistd.h>

#include <R_ext/Rallocators.h>

SEXP processx__mmap_pack(SEXP filename, SEXP data) {
  const char *c_filename = CHAR(STRING_ELT(filename, 0));
  R_xlen_t i, n = XLENGTH(data);
  static int sexpsize = sizeof(SEXPTYPE);
  static int xlensize = sizeof(R_xlen_t);
  static int lglsize = sizeof(LOGICAL(ScalarLogical(0))[0]);
  static int intsize = sizeof(INTEGER(ScalarInteger(0))[0]);
  static int realsize = sizeof(REAL(ScalarReal(0))[0]);
  static int sexprecsize = sizeof(SEXPREC_ALIGN);
  static int allocatorsize = sizeof(R_allocator_t);
  int elementsize = sexpsize + xlensize + allocatorsize + sexprecsize;
  /* Full length + number of elements + data */
  R_xlen_t fullsize = xlensize + xlensize + elementsize * n;
  void *map_orig, *map;

  /* Calculate the size we need */
  for (i = 0; i < n; i++) {
    SEXP elt = VECTOR_ELT(data, i);
    SEXPTYPE type = TYPEOF(elt);
    R_xlen_t len = XLENGTH(elt);
    int eltsize = -1;           /* -1 to avoid gcc warning */
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
      R_THROW_ERROR("Unsupported type in mmap packing");
    }
    fullsize += len * eltsize;
  }

  int fd = open(c_filename, O_RDWR | O_CREAT | O_TRUNC, 0644);
  if (fd == -1) {
    R_THROW_SYSTEM_ERROR("Cannot open file '%s'", c_filename);
  }
  if (unlink(c_filename) == -1) {
    R_THROW_SYSTEM_ERROR("Cannot delete file '%s'", c_filename);
  }
  if (ftruncate(fd, fullsize) == -1) {
    R_THROW_SYSTEM_ERROR("Cannot truncate file '%s'", c_filename);
  }

  /* Do not close on exec */
  processx__cloexec_fcntl(fd, 0);

  map = map_orig = mmap(
    NULL, fullsize, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fd, 0);

  if (map == MAP_FAILED) R_THROW_SYSTEM_ERROR("mmap failed");

  /* Need to copy the elements in place */
  /* Full length, thne number of elements */
  memcpy(map, &fullsize, xlensize);
  map += xlensize;
  memcpy(map, &n, xlensize);
  map += xlensize;

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
    int eltsize = -1;           /* To avoid a C compiler warning */
    void *src;
    switch (type) {
    case LGLSXP:
      eltsize = lglsize;
      src = LOGICAL(elt);
      break;
    case INTSXP:
      eltsize = intsize;
      src = INTEGER(elt);
      break;
    case REALSXP:
      eltsize = realsize;
      src = REAL(elt);
      break;
    case RAWSXP:
      eltsize = 1;
      src = RAW(elt);
      break;
    default:
      R_THROW_ERROR("Unsupported type in mmap packing");
    }
    map += sexprecsize + allocatorsize;
    memcpy(map, src, eltsize * len);
    map += eltsize * len;
  }

  if (msync(map_orig, fullsize, MS_SYNC) == -1) {
    R_THROW_SYSTEM_ERROR("Cannot sync mmap");
  }

  if (munmap(map_orig, fullsize) == -1) {
    R_THROW_SYSTEM_ERROR("Cannot unmap mmap");
  }

  SEXP ret = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(ret, 0, ScalarInteger(fd));
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

SEXP processx__mmap_unpack(SEXP fd) {
  SEXP ret = R_NilValue;
  int c_fd = INTEGER(fd)[0];
  R_xlen_t fullsize;
  static int sexpsize = sizeof(SEXPTYPE);
  static int xlensize = sizeof(R_xlen_t);
  static int lglsize = sizeof(LOGICAL(ScalarLogical(0))[0]);
  static int intsize = sizeof(INTEGER(ScalarInteger(0))[0]);
  static int realsize = sizeof(REAL(ScalarReal(0))[0]);
  static int sexprecsize = sizeof(SEXPREC_ALIGN);
  static int allocatorsize = sizeof(R_allocator_t);
  R_xlen_t i, n;
  void *map, *map_orig;

  /* First mmap to get the correct size */
  map = mmap(NULL, xlensize, PROT_READ, MAP_FILE | MAP_PRIVATE, c_fd, 0);
  if (map == MAP_FAILED) R_THROW_SYSTEM_ERROR("mmap failed");
  memcpy(&fullsize, map, xlensize);
  if (munmap(map, xlensize) == -1) R_THROW_SYSTEM_ERROR("munmap failed");

  /* OK, now we know the size */
  map = map_orig = mmap(NULL, fullsize, PROT_READ | PROT_WRITE,
                   MAP_FILE | MAP_PRIVATE, c_fd, 0);
  close(c_fd);
  if (map == MAP_FAILED) R_THROW_SYSTEM_ERROR("mmap failed");

  /* skip fullsize, we have that already. */
  map += xlensize;
  memcpy(&n, map, xlensize);
  map += xlensize;
  ret = PROTECT(allocVector(VECSXP, n));
  void *data = map + n * (sexpsize + xlensize);

  struct R_allocator allocator =
    { processx__alloc, processx__free, NULL, NULL };

  for (i = 0; i < n; i++) {
    SEXPTYPE type;
    R_xlen_t len;
    int eltsize = -1;           /* To avoid a compiler warning */
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
      R_THROW_ERROR("Unsupported type in mmap unpacking");
    }

    allocator.data = data;
    SET_VECTOR_ELT(ret, i, allocVector3(type, len, &allocator));
    data += sexprecsize + allocatorsize + len * eltsize;
  }

  UNPROTECT(1);
  return ret;
}
