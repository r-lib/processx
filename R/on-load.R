
.onLoad <- function(libname, pkgname) {
  debugme::debugme()                    # nocov
}

.onUnload <- function(libpath) {
  if (os_type() != "windows") .Call(c_processx__killem_all)
}
