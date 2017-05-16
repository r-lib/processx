
.onLoad <- function(libname, pkgname) {
  debugme::debugme()                    # nocov
}

.onUnload <- function(libpath) {
  .Call(c_processx__killem_all)
}
