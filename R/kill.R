
#' Kill a process
#'
#' @param self this
#' @param private this.private
#' @param grace Deprecated and ignored.
#'
#' The process might not be running any more, but \code{tools::pskill}
#' does not seem to care about whether it could actually kill the
#' process or not. To be sure, that this workds on all platforms,
#' we put it in a `tryCatch()`
#'
#' A killed process can be restarted.
#'
#' @keywords internal
#' @importFrom tools pskill SIGKILL SIGTERM

process_kill <- function(self, private, grace) {
  "!DEBUG process_kill '`private$get_short_name()`', pid `private$pid`"
  .Call("processx_kill", private$handle[[2]])

  ## This is to collect the exit status
  self$is_alive()

  invisible(self)
}
