
.onLoad <- function(libname, pkgname) {
  supervisor_reset()
  if (requireNamespace("debugme", quietly = TRUE)) debugme::debugme() # nocov
}

.onUnload <- function(libpath) {
  if (os_type() != "windows") .Call(c_processx__killem_all)
  supervisor_reset()
}
