# These functions are used on Windows. On Unixes, the functions still exist,
# but they will throw errors.

#' @useDynLib processx C_createNamedPipe
create_named_pipe <- function(name, mode = "r") {
  structure(
    .Call(C_createNamedPipe, name, mode),
    class = "named_pipe"
  )
}


#' @useDynLib processx C_closeNamedPipe
close_named_pipe <- function(pipe = NULL) {
  if (!is.named_pipe(pipe))
    stop("`pipe` must be a named_pipe object.")

  .Call(C_closeNamedPipe, pipe)
}


#' @useDynLib processx C_writeNamedPipe
write_named_pipe <- function(text, pipe = NULL) {
  if (!is.named_pipe(pipe))
    stop("`pipe` must be a named_pipe object.")

  .Call(C_writeNamedPipe, text, pipe)
}

is.named_pipe <- function(x) {
  inherits(x, "named_pipe")
}
