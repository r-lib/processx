
exec <- function(command, args = character(), stdout = NULL, stderr = NULL,
                 detached = FALSE, windows_verbatim_args = FALSE,
		 windows_hide_window = FALSE) {

  .Call("processx_exec", command, c(command, args), stdout, stderr,
        detached, windows_verbatim_args, windows_hide_window, PACKAGE = "processx")
}

wait <- function(pid, hang = FALSE) {

  .Call("processx_wait", as.integer(pid), as.logical(hang),
        PACKAGE = "processx")
}
