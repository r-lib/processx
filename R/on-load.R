
Internal <- NULL

.onLoad <- function(libname, pkgname) {
  ## Copy the shared lib to the session temporary directory
  copy_lib(libname, pkgname)

  ## This is to circumvent a ps bug
  if (ps::ps_is_supported()) ps::ps_handle()
  supervisor_reset()
  Internal <<- get(".Internal", asNamespace("base"))
  if (requireNamespace("debugme", quietly = TRUE)) debugme::debugme() # nocov
}

.onUnload <- function(libpath) {
  if (os_type() != "windows") .Call(c_processx__killem_all)
  supervisor_reset()
}

copy_lib <- function(libname, pkgname) {
  libs <- .dynLibs()
  matchidx <- vapply(libs, "[[", character(1), "name") == pkgname
  pkglibs <- libs[matchidx]
  for (lib in pkglibs) {
    dyn.unload(lib[["path"]])
  }
  .dynLibs(libs[!(libs %in% pkglibs)])

  dir.create(tmp <- tempfile(.packageName))
  tmp <- normalizePath(tmp)
  libdir <- file.path(tmp, pkgname, "libs", .Platform$r_arch)
  dir.create(libdir, recursive = TRUE)

  ext <- .Platform$dynlib.ext

  ## This is for pkgload / devtools
  lib1 <- file.path(libname, pkgname, "src", paste0(pkgname, ext))
  if (file.exists(lib1)) file.copy(lib1, libdir)

  ## This is the proper R CMD INSTALL
  lib2 <- file.path(libname, pkgname, "libs", .Platform$r_arch,
                    paste0(pkgname, ext))
  if (file.exists(lib2)) file.copy(lib2, libdir)

  ## Plus we need these as well
  file.copy(
    file.path(libname, pkgname, c("DESCRIPTION", "NAMESPACE")),
    file.path(tmp, pkgname))

  dll <- library.dynam(pkgname, pkgname, lib.loc = tmp)

  syms <- names(getDLLRegisteredRoutines(dll)$.Call)
  routines <- getNativeSymbolInfo(syms, dll)
  ns <- asNamespace(pkgname)

  ns$.__NAMESPACE__.$DLLs[[.packageName]] <- dll
  for (n in names(routines)) ns[[paste0("c_", n)]] <- routines[[n]]

  ## Put a finalizer on the namespace, to unload the DLL
  finalizer <- function(x) {
    libs <- .dynLibs()
    matchidx <- vapply(libs, "[[", character(1), "name") == "processx"
    pkglibs <- libs[matchidx]
    for (lib in pkglibs) {
      dyn.unload(lib[["path"]])
    }
    .dynLibs(libs[!(libs %in% pkglibs)])
  }

  ## To avoid keeping this lexical scope alive
  environment(finalizer) <- .GlobalEnv

  reg.finalizer(ns, finalizer, onexit = TRUE)

  invisible()
}
