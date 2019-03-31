
process__exists <- function(pid) {
  safecall(c_processx__process_exists, pid)
}
