
safe_system <- function(command, args) {

  out <- tempfile()
  err <- tempfile()
  on.exit(unlink(out), add = TRUE)
  on.exit(unlink(err), add = TRUE)

  ## We suppress warnings, they are given if the command
  ## exits with a non-zero status
  suppressWarnings(
    res <- system2(command, args = args, stdout = out, stderr = err)
  )

  list(
    stdout = win2unix(read_char(out)),
    stderr = win2unix(read_char(err)),
    status = res
  )
}

win2unix <- function(str) {
  gsub("\r\n", "\n", str, fixed = TRUE)
}

read_char <- function(path, ...) {
  readChar(path, nchars = file.info(path)$size, ...)
}
