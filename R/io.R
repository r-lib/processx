
process_read_output_lines <- function(self, private) {
  "!DEBUG process_read_output_lines `private$get_short_name()`"
  .Call("processx_read_output_lines", private$status, PACKAGE = "processx")
}

process_read_output <- function(self, private) {
  "!DEBUG process_read_output `private$get_short_name()`"
  .Call("processx_read_output", private$status, PACKAGE = "processx")
}

process_read_error_lines <- function(self, private) {
  "!DEBUG process_read_error_lines `private$get_short_name()`"
  .Call("processx_read_error_lines", private$status, PACKAGE = "processx")
}

process_read_error <- function(self, private) {
  "!DEBUG process_read_error `private$get_short_name()`"
  .Call("processx_read_error", private$status, PACKAGE = "processx")
}

process_can_read_output <- function(self, private) {
  "!DEBUG process_can_read_output `private$get_short_name()`"
  .Call("processx_can_read_output", private$status, PACKAGE = "processx")
}

process_can_read_error <- function(self, private) {
  "!DEBUG process_can_read_error `private$get_short_name()`"
  .Call("processx_can_read_error", private$status, PACKAGE = "processx")
}

process_is_eof_output <- function(self, private) {
  "!DEBUG process_is_eof_output  `private$get_short_name()`"
  .Call("processx_is_eof_output", private$status)
}

process_is_eof_error <- function(self, private) {
  "!DEBUG process_is_eof_error `private$get_short_name()`"
  .Call("processx_is_eof_error", private$status)
}
