
process_get_output_connection <- function(self, private) {
  "!DEBUG process_get_output_connection `private$get_short_name()`"
  .Call("processx_get_output_connection", private$status,
        PACKAGE = "processx")
}

process_get_error_connection <- function(self, private) {
  "!DEBUG process_get_error_connection `private$get_short_name()`"
  .Call("processx_get_error_connection", private$status,
        PACKAGE = "processx")
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
