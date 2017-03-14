
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
  "!DEBUG process_kill '`private$get_short_name()`', pid `private$pid`"
  if (is.null(private$status)) {
    pids <- c(
      private$pid,
      get_pid_tree(private$pid)
    )

    pskill(pids, SIGTERM)
    Sys.sleep(grace)
    pskill(pids, SIGKILL)

    private$pid <- NULL
  }

  invisible(self)
}
