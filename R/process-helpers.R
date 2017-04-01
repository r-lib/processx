
process__exists <- function(pid) {
  .Call("processx__process_exists", pid, PACKAGE = "processx")
}
