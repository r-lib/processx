
exec <- function(command, args = character(), stdout = NULL, stderr = NULL,
                 detached = FALSE) {

  .Call("processx_exec", command, c(command, args), stdout, stderr,
        detached, PACKAGE = "processx")
}
