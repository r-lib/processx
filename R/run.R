
#' Run external command, and wait until finishes
#'
#' `run` provides an interface similar to [base::system()] and
#' [base::system2()], but based on the [process] class. This allows some
#' extra features, see below.
#'
#' `run` supports
#' * Specifying a timeout for the command. If the specified time has
#'   passed, and the process is still running, it will be killed
#'   (with all its child processes).
#' * Calling a callback function for each line of the standard output
#'   and/or error.
#'
#' @section Callbacks:
#'
#' Some notes about the callback functions. The first argument of a
#' callback function is a character scalar (length 1 character), a single
#' output or error line. The second argument is always the [process]
#' object. You can manipulate this object, for example you can call
#' `$kill()` on it to terminate it, as a response to a message on the
#' standard output or error.
#'
#' @param command Character scalar, the command to run. It will be
#'   escaped via [base::shQuote].
#' @param args Character vector, arguments to the command. They will be
#'   escaped via [base::shQuote].
#' @param commandline A character scalar, a full command line.
#'   No escaping will be performed on it.
#' @param timeout Timeout for the process, in seconds, or as a `difftime`
#'   object. If it is not finished before this, it will be killed.
#' @param stdout_callback `NULL`, or a function to call for every line
#'   of the standard output. See more below.
#' @param stderr_callback `NULL`, or a function to call for every line
#'   of the standard error. See more below.
#' @param check_interval How often to check on the process for output.
#'   This is only used if the process had no output at the last check.
#'   If a process continuously produces output, then `run` does not
#'   wait at all.
#' @return A list with components:
#'   * status The exit status of the process. If this is `NA`, then the
#'     process was killed and had no exit status.
#'   * stdout The standard output of the command, in a character vector.
#'   * stderr The standard error of the command, in a character vector.
#'
#' @export
#' @examples
#' ## Different examples for Unix and Windows
#' if (.Platform$OS.type == "unix") {
#'   run("ls")
#'   system.time(run(commandline = "sleep 10", timeout = 1))
#'   system.time(
#'     run(
#'       commandline = "for i in 1 2 3 4 5; do echo $i; sleep 1; done",
#'       timeout=2
#'     )
#'   )
#' } else {
#'   run(commandline = "ping -n 1 127.0.0.1")
#'   run(commandline = "ping -n 6 127.0.0.1", timeout = 1)
#' }
#'

run <- function(
  command = NULL, args = character(), commandline = NULL, timeout = Inf,
  stdout_callback = NULL, stderr_callback = NULL, check_interval = 0.01) {

  assert_that(is_time_interval(timeout))
  assert_that(is.null(stdout_callback) || is.function(stdout_callback))
  assert_that(is.null(stderr_callback) || is.function(stderr_callback))
  assert_that(is_time_interval(check_interval))
  ## The rest is checked by process$new()

  ## Run the process
  pr <- process$new(command, args, commandline)

  ## Shall we just wait, or do sg while waiting?
  if (timeout == Inf && is.null(stdout_callback) &&
      is.null(stderr_callback)) {
    pr$wait()
    list(
      status = pr$get_exit_status(),
      stdout = pr$read_output_lines(),
      stderr = pr$read_error_lines()
    )

  } else {
    run_manage(pr, timeout, stdout_callback, stderr_callback,
               check_interval)
  }
}

run_manage <- function(proc, timeout, stdout_callback,
                       stderr_callback, check_interval) {

  timeout <- as.difftime(timeout, units = "secs")
  start_time <- proc$get_start_time()

  stdout <- character()
  stderr <- character()

  do_output <- function() {
    had_output <- FALSE
    ## stdout callback
    if (!is.null(stdout_callback)) {
      newout <- proc$read_output_lines()
      lapply(newout, function(x) stdout_callback(x, proc))
      stdout <<- c(stdout, newout)
      had_output <- length(newout) > 0
    }

    ## stderr callback
    if (!is.null(stderr_callback)) {
      newerr <- proc$read_error_lines()
      lapply(newerr, function(x) stderr_callback(x, proc))
      stderr <<- c(stderr, newerr)
      had_output <- had_output || length(newerr) > 0
    }
    had_output
  }

  while (proc$is_alive()) {

    ## timeout, maybe finished by now
    if (!is.null(timeout) && Sys.time() - start_time > timeout) {
      proc$kill()
    }

    ## Only sleep if there was no output
    if (!do_output()) Sys.sleep(check_interval)
  }

  ## Needed to get the exit status
  proc$wait()

  ## We might still have output
  do_output()

  if (is.null(stdout_callback)) stdout <- proc$read_output_lines()
  if (is.null(stderr_callback)) stderr <- proc$read_error_lines()

  list(
    status = proc$get_exit_status(),
    stdout = stdout,
    stderr = stderr
  )
}
