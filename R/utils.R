
os_type <- function() {
  .Platform$OS.type
}

null_file <- function() {
  if (os_type() == "windows") {
    "NUL"
  } else {
    "/dev/null"
  }
}

isFALSE <- function(x) {
  identical(FALSE, x)
}

is_closed <- function(x) {
  if (!inherits(x, "connection")) stop("Not a connection")
  ! x %in% getAllConnections()
}

## We do not call `isOpen`, because it fails on a closed
## connection. (!) close(x), however seems to work just fine
## on a closed connection.

close_if_needed <- function(x) {
  if (inherits(x, "connection") && is_closed(x)) close(x)
}
