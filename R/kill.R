
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

    ## Children
    kill_children(private$pid, SIGTERM)
    Sys.sleep(grace)
    kill_children(private$pid, SIGKILL)

    ## Process itself
    pskill(as.integer(private$pid), SIGTERM)
    Sys.sleep(grace)
    pskill(as.integer(private$pid), SIGKILL)
  }

  private$pid <- get_pid_by_name(private$name)

  invisible(self)
}

kill_children <- function(pids, signal) {
  if (os_type() == "windows") {
    kill_children_windows(pids, signal)
  } else {
    kill_children_unix(pids, signal)
  }
}

kill_children_windows <- function(pids, signal) {
  children <- unlist(lapply(as.integer(pids), get_children))
  if (length(children) == 0) return()
  pskill(children, signal)
}

kill_children_unix <- function(pids, signal) {
  safe_system(
    "pkill",
    c(paste0("-", signal), "-P", pids)
  )
}
