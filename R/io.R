
process_read_output_lines <- function(self, private, ...) {
  "!DEBUG process_read_output_lines `private$get_short_name()`"
  private$stdout <- open_if_needed(private$stdout)
  readLines(private$stdout, ...)
}


process_read_error_lines <- function(self, private, ...) {
  "!DEBUG process_read_error_lines `private$get_short_name()`"
  private$stderr <- open_if_needed(private$stderr)
  readLines(private$stderr, ...)
}


process_can_read_output <- function(self, private) {
  "!DEBUG process_can_read_output `private$get_short_name()`"
  process_can_read(self, private, "stdout")
}


process_can_read_error <- function(self, private) {
  "!DEBUG process_can_read_error `private$get_short_name()`"
  process_can_read(self, private, "stderr")
}


process_can_read <- function(self, private, conn) {
  "!DEBUG process_can_read `private$get_short_name()`"
  private[[conn]] <- open_if_needed(private[[conn]])

  ## If there is pushback, then there is definitely
  ## something to read
  if (pushBackLength(private[[conn]]) > 0) {
    TRUE

  ## Otherwise we try to read a line and push it back
  ## if we succeeded
  } else {
    lines <- readLines(private[[conn]], n = 1)

    if (length(lines)) {
      pushBack(lines, private[[conn]])
      TRUE
    } else {
      FALSE
    }
  }
}

process_is_eof_output <- function(self, private) {
  "!DEBUG process_is_eof_output  `private$get_short_name()`"
  process_is_eof(self, private, "stdout")
}

process_is_eof_error <- function(self, private) {
  "!DEBUG process_is_eof_error `private$get_short_name()`"
  process_is_eof(self, private, "stderr")
}

process_is_eof <- function(self, private, conn) {
  "!DEBUG process_is_eof `private$get_short_name()`"
  ! process_can_read(self, private, conn) &&
  ! process_is_alive(self, private)
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
  "!DEBUG open_if_needed"

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
    process_connection(file(con, open = "r", blocking = FALSE))

  ## (4)
  } else {
    con
  }
}
