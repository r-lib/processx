
process__exists <- function(pid) {
  entrace_call(c_processx__process_exists, pid)
}
