
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

close_if_needed <- function(x) {
  if (inherits(x, "connection")) close(x)
}
