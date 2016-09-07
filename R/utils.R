
os_type <- function() {
  .Platform$OS.type
}

is_linux <- function() {
  identical(tolower(Sys.info()[["sysname"]]), "linux")
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

check_tool <- function(x) {
  if (Sys.which(x) == "") {
    stop(
      "Could not run '", x,
      "', 'process' needs '", x, "' on this platform"
    )
  }
}
