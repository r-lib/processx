
#' Kill a process
#'
#' @param self this
#' @param private this.private
#' @param grace Numeric scalar, grace period between sending a TERM
#'   and a KILL signal, in seconds.
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
  if (! is.null(private$pid)) {
    pids <- get_pid_tree_by_name(private$name)
    pskill(pids, SIGTERM)
    Sys.sleep(grace)
    pskill(pids, SIGKILL)
  }

  private$pid <- get_pid_by_name(private$name)

  invisible(self)
}
