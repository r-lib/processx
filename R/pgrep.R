
## pgrep does not include itself in the output, but on some systems
## (e.g. Linux) it does include its ancestors, which is a problem for us
## Here we make sure that ancestors are excluded on Linux

pgrep_children <- function(pid) {
  if (is_linux()) {
    pgrep_children_linux(pid)

  } else {
    pgrep_children_unix(pid)
  }
}

## Some old Linux systems do not support pgrep -a, so we cannot filter the
## processes based on their command line. We get all child processes
## including pgrep's ancestors, and then use ps to list them again.
## This effectively filters out pgrep and its ancestors.

pgrep_children_linux <- function(pid) {
  allproc <- safe_system("pgrep", c("-d,", pid))
  safe_system(
    "ps",
    c("-o", "pid", "--no-header", "-p", str_trim(allproc$stdout))
  )
}

pgrep_children_unix <- function(pid) {
  safe_system("pgrep", c("-P", pid))
}
