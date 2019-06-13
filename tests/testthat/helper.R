
skip_other_platforms <- function(platform) {
  if (os_type() != platform) skip(paste("only run it on", platform))
}

skip_if_no_tool <- function(tool) {
  if (Sys.which(tool) == "") skip(paste0("`", tool, "` is not available"))
}

skip_extra_tests <- function() {
  if (Sys.getenv("PROCESSX_EXTRA_TESTS") ==  "") skip("no extra tests")
}

skip_if_no_ps <- function() {
  if (!requireNamespace("ps", quietly = TRUE)) skip("ps package needed")
  if (!ps::ps_is_supported()) skip("ps does not support this platform")
}

try_silently <- function(expr) {
  tryCatch(
    expr,
    error = function(x) "error",
    warning = function(x) "warning",
    message = function(x) "message"
  )
}

get_pid_by_name <- function(name) {
  if (os_type() == "windows") {
    get_pid_by_name_windows(name)
  } else if (is_linux()) {
    get_pid_by_name_linux(name)
  } else {
    get_pid_by_name_unix(name)
  }
}

get_pid_by_name_windows <- function(name) {
  ## TODO
}

## Linux does not exclude the ancestors of the pgrep process
## from the list, so we have to do that manually. We remove every
## process that contains 'pgrep' in its command line, which is
## not the proper solution, but for testing it will do.
##
## Unfortunately Ubuntu 12.04 pgrep does not have a -a switch,
## so we cannot just output the full command line and then filter
## it in R. So we first run pgrep to get all matching process ids
## (without their command lines), and then use ps to list the processes
## again. At this time the first pgrep process is not running any
## more, but another process might have its id, so we filter again the
## result for 'name'

get_pid_by_name_linux <- function(name) {
  ## TODO
}

skip_in_covr <- function() {
  if (Sys.getenv("R_COVR", "") == "true") skip("in covr")
}

httpbin <- local({
  cache <- NULL
  function(url = "") {
    if (is.null(cache)) cache <<- curl::nslookup("eu.httpbin.org")
    paste0("http://", cache, url)
  }
})

interrupt_me <- function(expr, after = 1) {
  tryCatch({
    p <- callr::r_bg(function(pid, after) {
      Sys.sleep(after)
      ps::ps_interrupt(ps::ps_handle(pid))
    }, list(pid = Sys.getpid(), after = after))
    expr
    p$kill()
  }, interrupt = function(e) e)
}

expect_error <- function(..., class = "error") {
  testthat::expect_error(..., class = class)
}
