
#' @useDynLib processx
NULL

#' External process
#'
#' Managing external processes from R is not trivial, and this
#' class aims to help with this deficiency. It is essentially a small
#' wrapper around the \code{system} base R function, to return the process
#' id of the started process, and set its standard output and error
#' streams. The process id is then used to manage the process.
#'
#' @section Usage:
#' \preformatted{p <- process$new(command = NULL, args, commandline = NULL,
#'                  stdout = TRUE, stderr = TRUE, cleanup = TRUE,
#'                  echo_cmd = FALSE)
#'
#' p$is_alive()
#' p$kill(grace = 0.1)
#' p$wait()
#' p$get_exit_status()
#' p$restart()
#'
#' p$read_output_lines(...)
#' p$read_error_lines(...)
#' p$can_read_output()
#' p$can_read_error()
#' p$is_eof_output()
#' p$is_eof_error()
#' p$get_output_connection()
#' p$get_error_connection()
#'
#' print(p)
#' }
#'
#' @section Arguments:
#' \describe{
#'   \item{p}{A \code{process} object.}
#'   \item{command}{Character scalar, the command to run. It will be
#'     escaped via \code{\link[base]{shQuote}}.}
#'   \item{args}{Character vector, arguments to the command. They will be
#'     escaped via \code{\link[base]{shQuote}}.}
#'   \item{commandline}{A character scalar, a full command line.
#'     No escaping will be performed on it.}
#'   \item{stdout}{What to do with the standard output. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file.}
#'   \item{stdout}{What to do with the standard error. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file.}
#'   \item{cleanup}{Whether to kill the process if the \code{process}
#'     object is garbage collected.}
#'   \item{echo_cmd}{Whether to print the command to the screen before
#'     running it.}
#'   \item{grace}{Grace pediod between the TERM and KILL signals, in
#'     seconds.}
#'   \item{...}{Extra arguments are passed to the
#'     \code{\link[base]{readLines}} function.}
#' }
#'
#' @section Details:
#' \code{$new()} starts a new process, it uses \code{\link[base]{system}}.
#' R does \emph{not} wait for the process to finish, but returns
#' immediately.
#'
#' \code{$is_alive()} checks if the process is alive. Returns a logical
#' scalar.
#'
#' \code{$kill()} kills the process. It also kills all of its child
#' processes. First it sends the child processes a \code{TERM} signal, and
#' then after a grace period a \code{KILL} signal. Then it does the same
#' for the process itself. A killed process can be restarted using the
#' \code{restart} method. It returns the process itself.
#'
#' \code{$wait()} waits until the process finishes. Note that if the
#' process never finishes, then R will never regain control. It returns
#' the process itself.
#'
#' \code{$get_exit_code} returns the exit code of the process if it has
#' finished and \code{wait} was called on it. Otherwise it will return
#' \code{NULL}.
#'
#' \code{$restart()} restarts a process. It returns the process itself.
#'
#' \code{$read_output_lines()} reads from standard output of the process.
#' If the standard output was not requested, then it returns an error.
#' It uses a non-blocking text connection.
#'
#' \code{$read_error_lines()} is similar to \code{$read_output_lines}, but
#' it reads from the standard error stream.
#'
#' \code{$can_read_output()} checks if there is any standard output
#' immediately available.
#'
#' \code{$can_read_error()} checks if there is any standard error
#' immediately available.
#'
#' \code{$is_eof_output()} checks if the standard output stream has
#' ended. This means that the process is finished and all output has
#' been processed.
#'
#' \code{$is_eof_error()} checks if the standard error stream has
#' ended. This means that the process is finished and all output has
#' been processed.
#'
#' \code{$get_output_connection()} returns a connection object, to the
#' standard output stream of the process.
#'
#' \code{$get_error_conneciton()} returns a connection object, to the
#' standard error stream of the process.
#'
#' \code{print(p)} or \code{p$print()} shows some information about the
#' process on the screen, whether it is running and it's process id, etc.
#'
#' @importFrom R6 R6Class
#' @name process
#' @examples
#' # CRAN does not like long-running examples
#' \dontrun{
#' p <- process$new("sleep", "2")
#' p$is_alive()
#' p
#' p$kill()
#' p$is_alive()
#'
#' p$restart()
#' p$is_alive()
#' Sys.sleep(3)
#' p$is_alive()
#' }
#'
NULL

#' @export

process <- R6Class(
  "process",
  public = list(

    initialize = function(command = NULL, args = character(),
      commandline = NULL, stdout = TRUE, stderr = TRUE, cleanup = TRUE,
      echo_cmd = FALSE, windows_verbatim_args = FALSE,
      windows_hide_window = FALSE)
      process_initialize(self, private, command, args, commandline,
                         stdout, stderr, cleanup, echo_cmd,
                         windows_verbatim_args, windows_hide_window),

    kill = function(grace = 0.1)
      process_kill(self, private, grace),

    get_pid = function()
      process_get_pid(self, private),

    is_alive = function()
      process_is_alive(self, private),

    wait = function()
      process_wait(self, private),

    get_exit_status = function()
      process_get_exit_status(self, private),

    restart = function()
      process_restart(self, private),

    print = function()
      process_print(self, private),

    get_start_time = function()
      process_get_start_time(self, private),

    ## Output

    read_output_lines = function(...)
      process_read_output_lines(self, private, ...),

    read_error_lines = function(...)
      process_read_error_lines(self, private, ...),

    can_read_output = function()
      process_can_read_output(self, private),

    can_read_error = function()
      process_can_read_error(self, private),

    is_eof_output = function()
      process_is_eof_output(self, private),

    is_eof_error = function()
      process_is_eof_error(self, private),

    get_output_connection = function()
      process_get_output_connection(self, private),

    get_error_connection = function()
      process_get_error_connection(self, private)

  ),

  private = list(

    handle = NULL,        # OS specific handle of the process
    command = NULL,       # Save 'command' argument here
    args = NULL,          # Save 'args' argument here
    commandline = NULL,   # The full command line
    cleanup = NULL,       # cleanup argument
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    pstdout = NULL,       # the original stdout argument
    pstderr = NULL,       # the original stderr argument
    cleanfiles = NULL,    # which temp stdout/stderr file(s) to clean up
    status = NULL,        # Exit status of the process
    signal = NULL,        # signal that killed it (if any)
    starttime = NULL,     # timestamp of start
    statusfile = NULL,    # file for the exit status
    echo_cmd = NULL,      # whetheer to echo the command
    windows_verbatim_args = NULL,
    windows_hide_window = NULL,

    get_short_name = function()
      process_get_short_name(self, private)
  )
)

process_is_alive <- function(self, private) {
  "!DEBUG process_is_alive `private$get_short_name()`"
  if (! is.null(private$status)) {
    FALSE

  } else {
    res <- wait(private$handle[[2]], hang = FALSE)
    if (res[[1]] == 2) {
      private$status <- private$signal <- NA_integer_
      FALSE

    } else if (res[[1]] == 0) {
      private$status <- res[[2]]
      private$signal <- res[[3]]
      FALSE

    } else {
      TRUE
    }
  }
}

process_restart <- function(self, private) {

  "!DEBUG process_restart `private$get_short_name()`"

  ## Suicide if still alive
  if (self$is_alive()) self$kill()

  ## Wipe out state, to be sure
  private$handle <- NULL
  private$cleanfiles <- NULL
  private$status <- NULL
  private$signal <- NULL

  process_initialize(
    self,
    private,
    private$command,
    private$args,
    private$commandline,
    private$pstdout,
    private$pstderr,
    private$cleanup,
    private$echo_cmd,
    private$windows_verbatim_args,
    private$windows_hide_window
  )

  invisible(self)
}

process_wait <- function(self, private) {
  "!DEBUG process_wait `private$get_short_name()`"
  if (is.null(private$status)) {
    res <- wait(private$handle[[2]], hang = TRUE)
    if (res[[1]] == 2) {
      private$status <- private$signal <- NA_integer_

    } else if (res[[1]] == 0) {
      private$status <- res[[2]]
      private$signal <- res[[3]]
    }
  }
  invisible(self)
}

process_get_exit_status <- function(self, private) {
  private$status
}

process_get_start_time <- function(self, private) {
  private$starttime
}

process_get_pid <- function(self, private) {
  private$handle[[1]]
}
