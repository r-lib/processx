
## nocov start

.onLoad <- function(libname, pkgname) {
  ## This is to circumvent a ps bug
  if (ps::ps_is_supported()) ps::ps_handle()
  supervisor_reset()
  if (Sys.getenv("DEBUGME", "") != "" &&
      requireNamespace("debugme", quietly = TRUE)) {
    debugme::debugme()
  }
}

.onUnload <- function(libpath) {
  .Call(c_processx__unload_cleanup)
  supervisor_reset()
}

## nocov end
