
process_get_output_connection <- function(self, private) {
  "!DEBUG process_get_output_connection `private$get_short_name()`"
  private$stdout_pipe
}

process_get_error_connection <- function(self, private) {
  "!DEBUG process_get_error_connection `private$get_short_name()`"
  private$stderr_pipe
}

process_read_output_lines <- function(self, private, ...) {
  "!DEBUG process_read_output_lines `private$get_short_name()`"
  readLines(process_get_output_connection(self, private), ...)
}

process_read_error_lines <- function(self, private, ...) {
  "!DEBUG process_read_error_lines `private$get_short_name()`"
  readLines(process_get_error_connection(self, private), ...)
}

process_is_incompelete_output <- function(self, private) {
  isIncomplete(process_get_output_connection(self, private))
}

process_is_incompelete_error <- function(self, private) {
  isIncomplete(process_get_error_connection(self, private))
}

poll_codes <- c("nopipe", "ready", "timeout", "closed", "silent")

process_poll_io <- function(self, private, ms) {
  res <- .Call("processx_poll_io", private$status, as.integer(ms),
               private$stdout_pipe, private$stderr_pipe, PACKAGE = "processx")

  structure(poll_codes[res], names = c("output", "error"))
}
