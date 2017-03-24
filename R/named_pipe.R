named_pipe_tempfile <- function(prefix = "pipe") {
  if (is_windows()) {
    # For some reason, calling tempfile("foo", tmpdir = "\\\\pipe\\.\\") takes
    # several seconds the first time it's called in an R session. So we'll do it
    # manually with paste0.
    paste0("\\\\.\\pipe", tempfile(prefix, ""))

  } else {
    tempfile(prefix)
  }
}


is_pipe_open <- function(pipe) {
  UseMethod("is_pipe_open")
}

#' @export
is_pipe_open.windows_named_pipe <- function(pipe) {
  # TODO: Implement this
  TRUE
}

#' @export
is_pipe_open.unix_named_pipe <- function(pipe) {
  # isOpen() gives an error when passed a closed fifo object, so this is a more
  # robust version.
  if (!inherits(pipe$handle, "fifo"))
    stop("pipe$handle must be a fifo object")

  is_open <- NA
  tryCatch(
    is_open <- isOpen(pipe$handle),
    error = function(e) { is_open <<- FALSE }
  )

  is_open
}


# These functions are an abstraction layer for named pipes. They're necessary
# because fifo() on Windows doesn't seem to work (as of R 3.3.3).

#' @useDynLib processx C_createNamedPipe
create_named_pipe <- function(name) {
  if (is_windows()) {
    structure(
      list(
        handle = .Call(C_createNamedPipe, name, "")
      ),
      class = c("windows_named_pipe", "named_pipe")
    )

  } else {
    structure(
      list(
        handle = fifo(name, "w+")
      ),
      class = c("unix_named_pipe", "named_pipe")
    )
  }
}


close_named_pipe <- function(pipe) {
  UseMethod("close_named_pipe")
}

#' @useDynLib processx C_closeNamedPipe
#' @export
close_named_pipe.windows_named_pipe <- function(pipe) {
  .Call(C_closeNamedPipe, pipe$handle)
}

#' @export
close_named_pipe.unix_named_pipe <- function(pipe) {
  close(pipe$handle)
}


write_named_pipe <- function(pipe, text) {
  UseMethod("write_named_pipe")
}

#' @useDynLib processx C_writeNamedPipe
#' @export
write_named_pipe.windows_named_pipe <- function(pipe, text) {
  text <- paste(text, collapse = "\n")
  .Call(C_writeNamedPipe, text, pipe$handle)
}

#' @useDynLib processx C_writeNamedPipe
#' @export
write_named_pipe.unix_named_pipe <- function(pipe, text) {
  writeLines(text, pipe$handle)
}
