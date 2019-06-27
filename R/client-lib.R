
load_client_lib <- function() {
  arch <- .Platform$r_arch
  ext <- .Platform$dynlib.ext
  sofile <- system.file(
    paste0("libs", arch), paste0("client", ext),
    package = "processx")

  # Try this as well, this is for devtools/pkgload
  if (sofile == "") {
    sofile <- system.file(
      "src", paste0("client", ext),
      package = "processx")
  }

  # stop() here and not throw(), because this function should be standalone
  if (sofile == "") stop("Cannot find client file")

  tmpsofile <- tempfile(fileext = ext)
  file.copy(sofile, tmpsofile)
  tmpsofile <- normalizePath(tmpsofile)

  lib <- dyn.load(tmpsofile)
  on.exit(dyn.unload(tmpsofile))

  sym_encode <- getNativeSymbolInfo("processx_base64_encode", lib)
  sym_decode <- getNativeSymbolInfo("processx_base64_decode", lib)
  sym_disinh <- getNativeSymbolInfo("processx_disable_inheritance", lib)
  sym_write  <- getNativeSymbolInfo("processx_write", lib)

  env <- new.env(parent = emptyenv())
  env$.path <- tmpsofile

  env$base64_encode <- function(x) rawToChar(.Call(sym_encode, x))
  env$base64_decode <- function(x) {
    if (is.character(x)) {
      x <- charToRaw(paste(gsub("\\s+", "", x), collapse = ""))
    }
    .Call(sym_decode, x)
  }

  env$disable_fd_inheritance <- function() .Call(sym_disinh)

  env$write_fd <- function(fd, data) {
    if (is.character(data)) data <- charToRaw(paste0(data, collapse = ""))
    len <- length(data)
    repeat {
      written <- .Call(sym_write, fd, data)
      len <- len - written
      if (len == 0) break
      if (written) data <- data[-(1:written)]
      Sys.sleep(.1)
    }
  }

  unload_client_lib <- unload_client_lib

  penv <- environment()
  parent.env(penv) <- baseenv()

  reg.finalizer(env, function(e) unload_client_lib(e), onexit = TRUE)

  ## Clear the cleanup method
  on.exit(NULL)
  env
}

unload_client_lib <- function(lib) {
  if (!is.null(lib$.path)) dyn.unload(lib$.path)
  rm(list = ls(lib, all.names = TRUE), envir = lib)
}
