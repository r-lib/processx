
process_print <- function(self, private) {

  state <- if (self$is_alive()) {
    pid <- self$get_pid()
    paste0("running, pid ", paste(pid, collapse = ", "), ".")
  } else {
    "finished."
  }

  cat(
    sep = "",
    "PROCESS ",
    "'", private$get_short_name(), "', ",
    state,
    "\n"
  )

  invisible(self)
}

process_get_short_name <- function(self, private) {
  if (!is.null(private$command)) {
    basename(private$command)
  } else if (nchar(private$commandline) < 40) {
    private$commandline
  } else {
    paste(substr(private$commandline, 1, 36), "...")
  }
}
