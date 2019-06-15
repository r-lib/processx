
#define USE_RINTERNALS

#include "processx.h"
#include "errors.h"

#ifdef _WIN32
#include <windows.h>
#include <inttypes.h>
#endif

static void processx__handle_finalizer(SEXP x) {
  void *addr = R_ExternalPtrAddr(x);
  if (!addr) {
    free(addr);
    R_ClearExternalPtr(x);
  }
}

SEXP processx_handle_create(SEXP desc) {
  int idesc = Rf_asInteger(desc);
  SEXP result;

#ifdef _WIN32
  HANDLE *handle = malloc(sizeof(HANDLE));
  if (!handle) R_THROW_SYSTEM_ERROR("Cannot create handle");
  UINT_PTR idesc2 = idesc;
  *handle = (HANDLE) idesc2;

#else
  int *handle = malloc(sizeof(int));
  if (!handle) R_THROW_SYSTEM_ERROR("Cannor create handle");
  *handle = idesc;
#endif

  result = PROTECT(R_MakeExternalPtr(handle, R_NilValue, R_NilValue));
  setAttrib(result, R_ClassSymbol, mkString("processx_handle"));

  R_RegisterCFinalizerEx(result, processx__handle_finalizer, (Rboolean) 0);

  UNPROTECT(1);
  return result;
}

SEXP processx_handle_describe(SEXP handle) {
  void *addr = R_ExternalPtrAddr(handle);
  char *buffer = R_alloc(1, 64);
  memset(buffer, 0, 64);
  if (!addr) R_THROW_ERROR("handle is a null pointer");

#ifdef _WIN32
  HANDLE *c_handle = (HANDLE*) addr;
  UINT_PTR idesc = (UINT_PTR)(*c_handle);
  snprintf(buffer, 64, PRIuPTR, idesc);
#else
  int *c_handle = (int*) addr;
  snprintf(buffer, 64, "%i", *c_handle);
#endif

  return mkString(buffer);
}
