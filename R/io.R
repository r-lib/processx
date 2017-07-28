
process_get_output_connection <- function(self, private) {
  "!DEBUG process_get_output_connection `private$get_short_name()`"

  # First time accessing connection when the output is a file (not pipe)
  if (is.null(private$stdout_pipe) &&
      !is.null(private$stdout) &&
      file.exists(private$stdout))
  {
    private$stdout_pipe <- file(private$stdout)

    # Need explicit open. Otherwise, each call to (e.g.) readLines() will open
    # and close the file. Use "rb" mode so that readChar() will preserve "\r\n"
    # on Windows.
    open(private$stdout_pipe, open = "rb")
  }

  private$stdout_pipe
}

process_get_error_connection <- function(self, private) {
  "!DEBUG process_get_error_connection `private$get_short_name()`"
  if (is.null(private$stderr_pipe) &&
      !is.null(private$stderr) &&
      file.exists(private$stderr))
  {
    private$stderr_pipe <- file(private$stderr)
    open(private$stderr_pipe, open = "rb")
  }

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

process_is_incomplete_output <- function(self, private) {
  isIncomplete(process_get_output_connection(self, private))
}

process_is_incomplete_error <- function(self, private) {
  isIncomplete(process_get_error_connection(self, private))
}

process_read_all_output <- function(self, private) {
  self$wait()

  con <- self$get_output_connection()
  if (private$stdout == "|") {
    result <- ""
    while (self$is_incomplete_output()) {
      self$poll_io(-1)
      result <- paste0(result, readChar(con, 1024))
    }
  }
  else {
    result <- read_char_all(con)
  }
  result
}

process_read_all_error <- function(self, private) {
  self$wait()

  con <- self$get_error_connection()
  if (private$stderr == "|") {
    result <- ""
    while (self$is_incomplete_error()) {
      self$poll_io(-1)
      result <- paste0(result, readChar(con, 1024))
    }
  }
  else {
    result <- read_char_all(con)
  }
  result
}

process_read_all_output_lines <- function(self, private, ...) {
  self$wait()
  results <- character()
  if (private$stdout == "|") {
    while (self$is_incomplete_output()) {
      self$poll_io(-1)
      results <- c(results, self$read_output_lines(...))
    }
  }
  else {
    results <- readLines(self$get_output_connection())
  }
  results
}

process_read_all_error_lines <- function(self, private, ...) {
  self$wait()
  results <- character()
  if (private$stderr == "|") {
    while (self$is_incomplete_error()) {
      self$poll_io(-1)
      results <- c(results, self$read_error_lines(...))
    }
  }
  else {
    results <- readLines(self$get_error_connection())
  }
  results
}

# Read all characters from a file or connection object and return it as a
# string.
read_char_all<- function(con) {
  if (is.character(con)) {
    # If it's a filename, simply read in the entire file in one go.
    result <- readChar(con, file.info(con)$size, useBytes = TRUE)
  }
  else if (inherits(con, "connection")) {
    # If it's a connection object, keep reading until no more is left.
    results <- character(0)

    # Read in reasonably sized blocks of text. Don't use useBytes=T, because it
    # could stop in the middle of a multi-byte character.
    txt <- readChar(con, nchars = 65536)
    while (length(txt) > 0) {
      results <- c(results, txt)
      txt <- readChar(con, nchars = 65536)
    }

    result <- paste(results, collapse = "")
  }
  else {
    stop("Don't know how to read from object of class ", class(con))
  }

  result
}

poll_codes <- c("nopipe", "ready", "timeout", "closed", "silent")

process_poll_io <- function(self, private, ms) {
  res <- .Call(c_processx_poll_io, private$status, as.integer(ms),
               private$stdout_pipe, private$stderr_pipe)

  structure(poll_codes[res], names = c("output", "error"))
}
