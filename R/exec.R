
exec <- function(command, args = character(), stdout = NULL, stderr = NULL,
                 detached = FALSE, windows_verbatim_args = FALSE,
		 windows_hide_window = TRUE) {

  .Call("processx_exec", command, c(command, args), stdout, stderr,
        detached, windows_verbatim_args, windows_hide_window, PACKAGE = "processx")
}
