
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

get_pid <- function(name) {

  res <- safe_system("pgrep", c("-f", name))

  ## This is the same on macOS, Solaris & Linux \o/
  ## 0   One or more processes matched
  ## 1   No processes matched
  ## 2   Syntax error in the command line
  ## 3   Internal error
  if (res$status > 1) {
    stop("Could not run 'pgrep'. 'process' needs 'pgrep' on this platform")
  }

  pid <- scan(text = res$stdout, what = 1, quiet = TRUE)

  ## Looks like system2() sometimes starts two shells, i.e. the first
  ## starts the second, with the same command line. We just take the
  ## last process in this case.

  if (length(pid) >= 1) {
    tail(sort(pid), 1)
  } else if (length(pid) == 0) {
    NULL
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
