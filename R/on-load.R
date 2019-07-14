
## nocov start

serialization_version <- NULL

.onLoad <- function(libname, pkgname) {
  ## This is to circumvent a ps bug
  if (ps::ps_is_supported()) ps::ps_handle()
  supervisor_reset()
  if (Sys.getenv("DEBUGME", "") != "" &&
      requireNamespace("debugme", quietly = TRUE)) {
    debugme::debugme()
  }
  serialization_version <<- if (getRversion() >= "3.5.0") 3L else 2L
}

.onUnload <- function(libpath) {
  rethrow_call(c_processx__unload_cleanup)
  supervisor_reset()
}

## nocov end
