
.onLoad <- function(libname, pkgname) {
  supervisor_reset()
  debugme::debugme()                    # nocov
}


.onUnload <- function(libpath) {
  supervisor_reset()
  cat("unloading dll", file=stderr())
  library.dynam.unload("processx", libpath)
  cat("unloaded dll", file=stderr())
}
