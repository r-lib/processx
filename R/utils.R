
os_type <- function() {
  .Platform$OS.type
}

is_windows <- function() {
  .Platform$OS.type == "windows"
}

is_osx <- function() {
  identical(Sys.info()[['sysname']], 'Darwin')
}

is_linux <- function() {
  identical(tolower(Sys.info()[["sysname"]]), "linux")
}

isFALSE <- function(x) {
  identical(FALSE, x)
}

`%||%` <- function(l, r) if (is.null(l)) r else l

last_char <- function(x) {
  nc <- nchar(x)
  substring(x, nc, nc)
}
