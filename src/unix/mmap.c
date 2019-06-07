
#define USE_RINTERNALS

#include "../processx.h"
#include "../errors.h"

#include <sys/mman.h>
#include <unistd.h>

#include <R_ext/Rallocators.h>

/* Pack an R object into shared memory
 *
 * `data` must be a list of: LGLSXP, INTSXP, REALSXP, RAWSXP.
 * Nested lists are not allowed currently. Attributes of the list or the
 * entries are dropped.
 *
 * The packed layout of the data is like this. First there is a global
 * header:
 *
 * - full length of the packed data, in bytes, R_xlen_t
 * - number of entries in the list , R_xlen_t
 *
 * Then comes a map of vectors, for each list entry we have:
 * - type of object, SEXPTYPE
 * - length of object, R_xlen_t
 *
 * Then come the objects themselves. These are a bit trickier, because we
 * want to avoid copying the data in the subprocess, via using a custom
 * allocator. To create R objects in place, we need to leave some space
 * before the actual vector data, for the SEXP header, and the allocator
 * as well. This means that for each object we'll have:
 *
 * - "empty" space of sizeof(SEXPPREC_ALIGN) + sizeof(R_allocator_t)
 * - then the object itself
 *
 */

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
  /* Full length, then number of elements */
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

/* Note: data seems useless here, it is just the allocator, again,
 * as a void*, from https://github.com/wch/r-source/blob/3a1ec60935e5aef5dff4794561d9e3ff2e30bd14/src/main/memory.c#L2545
 *     allocator->mem_free(allocator, (void*)allocator);
 */

/* Unpack data from shared memory.
 *
 * This is the inverse of pack().
 *
 * To create the R objects in-place, we need to know that when R allocates
 * memory for a vector, it allocates space for a header as well. The header
 * is sizeof(SEXPREC_ALIGN) + sizeof(R_allocator_t) bytes long. pack()
 * leaves this space out when packing the R vector to shared memory.
 * Our custom allocator just needs to return a pointer to the beginning
 * of the space where the header will be. Then everything automatically
 * falls into place.
 *
 * R will modify the header of course, but the shared memory has
 * copy-on-write semantics, so this is not a big deal. It does mean that
 * for each vector the OS will copy one or two extra memory pages, but
 * this should be OK, especially for longer vectors. (It is not possible
 * to make the R vector header non-contiguous with the data, AFAICT.)
 */

SEXP processx__mmap_unpack(SEXP fd) {
  SEXP ret = R_NilValue;
  int c_fd = INTEGER(fd)[0];
  R_xlen_t fullsize;
=======
SEXP processx__mmap_unpack(SEXP fd, SEXP size) {
  SEXP ret = R_NilValue;
  int c_fd = INTEGER(fd)[0];
  int c_size = INTEGER(size)[0];
>>>>>>> Unix mmap implementation poc
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
