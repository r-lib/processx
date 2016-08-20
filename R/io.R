
process_read_output_lines <- function(self, private, ...) {
  private$stdout <- open_if_needed(private$stdout)
  readLines(private$stdout, ...)
}


process_read_error_lines <- function(self, private, ...) {
  private$stderr <- open_if_needed(private$stderr)
  readLines(private$stderr, ...)
}


process_get_output_connection <- function(self, private) {
  private$stdout <- open_if_needed(private$stdout)
  private$stdout
}


process_get_error_connection <- function(self, private) {
  private$stderr <- open_if_needed(private$stderr)
  private$stderr
}

## Could be:
## (1) FALSE (connection was not requested)
## (2) closed connection
## (3) string = filename (not yet opened connection)
## (4) opened connection
##
## Order is important, as we cannot call isOpen on a closed
## connection. :/

open_if_needed <- function(con, what = "output") {

  ## (1)
  if (isFALSE(con)) {
    stop("Standard ", what, " was not kept, use 'stdout = TRUE'")
  }

  ## (2)
  if (inherits(con, "connection") && is_closed(con)) {
    stop("Connection was already closed")
  }

  ## (3)
  if (is_string(con)) {
    file(con, open = "r", blocking = FALSE)

  ## (4)
  } else {
    con
  }
}
