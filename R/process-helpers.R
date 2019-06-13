
process__exists <- function(pid) {
  rethrow_call(c_processx__process_exists, pid)
}
