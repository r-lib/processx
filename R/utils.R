
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

check_tool <- function(x) {
  if (Sys.which(x) == "") {
    stop(
      "Could not run '", x,
      "', 'process' needs '", x, "' on this platform"
    )
  }
}

str_trim <- function(x) {
  sub("\\s+$", "", sub("^\\s+", "", x))
}

wait_for_file <- function(file, check_interval = 0.01, timeout = 10) {
  tries <- max(timeout / check_interval, 1)
  for (i in 1:tries) {
    if (file.exists(file)) return(invisible(TRUE))
    Sys.sleep(check_interval)
  }
  stop("File was not created in ", timeout, " secs: ", file)
}
