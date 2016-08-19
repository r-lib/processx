
os_type <- function() {
  .Platform$OS.type
}

get_pid <- function(name) {

  res <- safe_system("pgrep", c("-f", name))

  ## This is the same on macOS, Solaris & Linux \o/
  ## 0   One or more processes matched
  ## 1   No processes matched
  ## 2   Syntax error in the command line
  ## 3   Internal error
  if (res$status > 1) {
    stop("Could not run 'pgrep'. 'exec' needs 'pgrep' on this platform")
  }

  pid <- scan(text = res$stdout, what = 1, quiet = TRUE)

  if (length(pid) == 1) {
    pid
  } else if (length(pid) == 0) {
    NULL
  } else {
    warning("Multiple processes found, internal error?")
    pid[1]
  }
}
