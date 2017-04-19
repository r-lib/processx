
process_write_control <- function(self, private, data) {
  writeBin(data, private$control_write)
}

process_read_control <- function(self, private, bytes) {
  readBin(private$control_read, "raw", n = bytes)
}

process_get_control_read_connection <- function(self, private) {
  private$control_read
}

process_get_control_write_connection <- function(self, private) {
  private$control_write
}

process_is_incomplete_control <- function(self, private) {
  isIncomplete(private$control_read)
}

process_poll_control <- function(self, private, timeout) {
  res <- .Call(c_processx_poll_control, private$status, as.integer(timeout),
               private$control_read)

  poll_codes[res]
}
