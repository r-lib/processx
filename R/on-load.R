
.onLoad <- function(libname, pkgname) {
  supervisor_reset()
  debugme::debugme()                    # nocov
}


.onUnload <- function(libpath) {
  supervisor_reset()
}
