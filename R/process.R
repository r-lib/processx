
#' @useDynLib processx, .registration = TRUE, .fixes = "c_"
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
#'                  echo_cmd = FALSE, windows_verbatim_args = FALSE,
#'                  windows_hide_window = FALSE)
#'
#' p$is_alive()
#' p$signal(signal)
#' p$kill(grace = 0.1)
#' p$wait(timeout = -1)
#' p$get_pid()
#' p$get_exit_status()
#' p$restart()
#' p$get_start_time()
#'
#' p$read_output_lines(...)
#' p$read_error_lines(...)
#' p$get_output_connection()
#' p$get_error_connection()
#' p$is_incomplete_output()
#' p$is_incomplete_error()
#' p$read_all_output()
#' p$read_all_error()
#' p$read_all_output_lines(...)
#' p$read_all_error_lines(...)
#'
#' p$poll_io(timeout)
#'
#' print(p)
#' }
#'
#' @section Arguments:
#' \describe{
#'   \item{p}{A \code{process} object.}
#'   \item{command}{Character scalar, the command to run.
#'     Note that this argument is not passed to a shell, so no
#'     tilde-expansion or variable substitution is performed on it.
#'     It should not be quoted with \code{\link[base]{shQuote}}. See
#'     \code{\link[base]{normalizePath}} for tilde-expansion.}
#'   \item{args}{Character vector, arguments to the command. They will be
#'     used as is, without a shell. They don't need to be escaped.}
#'   \item{commandline}{A character scalar, a full command line.
#'     On Unix systems it runs the a shell: \code{sh -c <commandline>}.
#'     On Windows it uses the \code{cmd} shell:
#'     \code{cmd /c <commandline>}. If you want more control, then call
#'     your chosen shell directly.}
#'   \item{stdout}{What to do with the standard output. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file, \code{"|"}: create an
#'     R connection for it.}
#'   \item{stderr}{What to do with the standard error. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file, \code{"|"}: create an
#'     R connection for it.}
#'   \item{cleanup}{Whether to kill the process (and its children)
#'     if the \code{process} object is garbage collected.}
#'   \item{echo_cmd}{Whether to print the command to the screen before
#'     running it.}
#'   \item{windows_verbatim_args}{Whether to omit quoting the arguments
#'     on Windows. It is ignored on other platforms.}
#'   \item{windows_hide_window}{Whether to hide the application's window
#'     on Windows. It is ignored on other platforms.}
#'   \item{signal}{An integer scalar, the id of the signal to send to
#'     the process. See \code{\link[tools]{pskill}} for the list of
#'     signals.}
#'   \item{grace}{Currently not used.}
#'   \item{timeout}{Timeout in milliseconds, for the wait or the I/O
#'     polling.}
#'   \item{...}{Extra arguments are passed to the
#'     \code{\link[base]{readLines}} function.}
#' }
#'
#' @section Details:
#' \code{$new()} starts a new process in the background, and then returns
#' immediately.
#'
#' \code{$is_alive()} checks if the process is alive. Returns a logical
#' scalar.
#'
#' \code{$signal()} sends a signal to the process. On Windows only the
#' \code{SIGINT}, \code{SIGTERM} and \code{SIGKILL} signals are interpreted,
#' and the special 0 signal, The first three all kill the process. The 0
#' signal return \code{TRUE} if the process is alive, and \code{FALSE}
#' otherwise. On Unix all signals are supported that the OS supports, and
#' the 0 signal as well.
#'
#' \code{$kill()} kills the process. It also kills all of its child
#' processes, except if they have created a new process group (on Unix),
#' or job object (on Windows). It returns \code{TRUE} if the process
#' was killed, and \code{FALSE} if it was no killed (because it was
#' already finished/dead when \code{processx} tried to kill it).
#'
#' \code{$wait()} waits until the process finishes, or a timeout happens.
#' Note that if the process never finishes, and the timeout is infinite
#' (the default), then R will never regain control. It returns
#' the process itself, invisibly.
#'
#' \code{$get_pid()} returns the process id of the process.
#'
#' \code{$get_exit_status} returns the exit code of the process if it has
#' finished and \code{NULL} otherwise.
#'
#' \code{$restart()} restarts a process. It returns the process itself.
#'
#' \code{$get_start_time()} returns the time when the process was
#' started.
#'
#' \code{$read_output_lines()} reads from standard output connection of
#' the process. If the standard output connection was not requested, then
#' then it returns an error. It uses a non-blocking text connection.
#'
#' \code{$read_error_lines()} is similar to \code{$read_output_lines}, but
#' it reads from the standard error stream.
#'
#' \code{$get_output_connection()} returns a connection object, to the
#' standard output stream of the process.
#'
#' \code{$get_error_conneciton()} returns a connection object, to the
#' standard error stream of the process.
#'
#' \code{$is_incomplete_output()} return \code{FALSE} if the other end of
#' the standard output connection was closed (most probably because the
#' process exited). It return \code{TRUE} otherwise.
#'
#' \code{$is_incomplete_error()} return \code{FALSE} if the other end of
#' the standard error connection was closed (most probably because the
#' process exited). It return \code{TRUE} otherwise.
#'
#' \code{$read_all_output()} waits for all standard output from the process.
#' It does not return until the process has finished.
#' Note that this process involves waiting for the process to finish,
#' polling for I/O and potentically several `readLines()` calls.
#' It returns a character scalar.
#'
#' \code{$read_all_error()} waits for all standard error from the process.
#' It does not return until the process has finished.
#' Note that this process involves waiting for the process to finish,
#' polling for I/O and potentically several `readLines()` calls.
#' It returns a character scalar.
#'
#' \code{$read_all_output_lines()} waits for all standard output lines
#' from a process. It does not return until the process has finished.
#' Note that this process involves waiting for the process to finish,
#' polling for I/O and potentically several `readLines()` calls.
#' It returns a character vector.
#'
#' \code{$read_all_error_lines()} waits for all standard error lines from
#' a process. It does not return until the process has finished.
#' Note that this process involves waiting for the process to finish,
#' polling for I/O and potentically several `readLines()` calls.
#' It returns a character vector.
#'
#' \code{$poll_io()} polls the process's connections for I/O. See more in
#' the \emph{Polling} section, and see also the \code{\link{poll}} function
#' to poll on multiple processes.
#'
#' \code{print(p)} or \code{p$print()} shows some information about the
#' process on the screen, whether it is running and it's process id, etc.
#'
#' @section Polling:
#' The \code{poll_io()} function polls the standard output and standard
#' error connections of a process, with a timeout. If there is output
#' in either of them, or they are closed (e.g. because the process exits)
#' \code{poll_io()} returns immediately.
#'
#' In addition to polling a single process, the \code{\link{poll}} function
#' can poll the output of several processes, and returns as soon as any
#' of them has generated output (or exited).
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

    signal = function(signal)
      process_signal(self, private, signal),

    get_pid = function()
      process_get_pid(self, private),

    is_alive = function()
      process_is_alive(self, private),

    wait = function(timeout = -1)
      process_wait(self, private, timeout),

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

    is_incomplete_output = function()
      process_is_incompelete_output(self, private),

    is_incomplete_error = function()
      process_is_incompelete_error(self, private),

    get_output_connection = function()
      process_get_output_connection(self, private),

    get_error_connection = function()
      process_get_error_connection(self, private),

    read_all_output = function()
      process_read_all_output(self, private),

    read_all_error = function()
      process_read_all_error(self, private),

    read_all_output_lines = function(...)
      process_read_all_output_lines(self, private, ...),

    read_all_error_lines = function(...)
      process_read_all_error_lines(self, private, ...),

    poll_io = function(timeout)
      process_poll_io(self, private, timeout)
  ),

  private = list(

    command = NULL,       # Save 'command' argument here
    args = NULL,          # Save 'args' argument here
    commandline = NULL,   # The full command line
    cleanup = NULL,       # cleanup argument
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    pstdout = NULL,       # the original stdout argument
    pstderr = NULL,       # the original stderr argument
    cleanfiles = NULL,    # which temp stdout/stderr file(s) to clean up
    starttime = NULL,     # timestamp of start
    echo_cmd = NULL,      # whether to echo the command
    windows_verbatim_args = NULL,
    windows_hide_window = NULL,

    status = NULL,        # C file handle
    exited = FALSE,       # Whether pid & exitcode was copied over here
    pid = NULL,           # pid, if finished, otherwise in status!
    exitcode = NULL,      # exit code, if finished, otherwise in status!

    stdout_pipe = NULL,
    stderr_pipe = NULL,

    get_short_name = function()
      process_get_short_name(self, private)
  )
)

process_restart <- function(self, private) {

  "!DEBUG process_restart `private$get_short_name()`"

  ## Suicide if still alive
  if (self$is_alive()) self$kill()

  ## Wipe out state, to be sure
  private$cleanfiles <- NULL
  private$status <- NULL
  private$exited <- FALSE
  private$pid <- NULL
  private$exitcode <- NULL
  private$stdout_pipe <- NULL
  private$stderr_pipe <- NULL

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

## See the C source code for a discussion about the implementation
## of these methods

process_wait <- function(self, private, timeout) {
  "!DEBUG process_wait `private$get_short_name()`"
  if (private$exited) {
    ## Nothing
  } else {
    .Call(c_processx_wait, private$status, as.integer(timeout))
  }
  invisible(self)
}

process_is_alive <- function(self, private) {
  "!DEBUG process_is_alive `private$get_short_name()`"
  if (private$exited) {
    FALSE
  } else {
    .Call(c_processx_is_alive, private$status)
  }
}

process_get_exit_status <- function(self, private) {
  "!DEBUG process_get_exit_status `private$get_short_name()`"
  if (private$exited) {
    private$exitcode
  } else {
    .Call(c_processx_get_exit_status, private$status)
  }
}

process_signal <- function(self, private, signal) {
  "!DEBUG process_signal `private$get_short_name()` `signal`"
  if (private$exited) {
    FALSE
  } else {
    .Call(c_processx_signal, private$status, as.integer(signal))
  }
}

process_kill <- function(self, private, grace) {
  "!DEBUG process_kill '`private$get_short_name()`', pid `private$get_pid()`"
  if (private$exited) {
    FALSE
  } else {
    .Call(c_processx_kill, private$status, as.numeric(grace))
  }
}

process_get_start_time <- function(self, private) {
  private$starttime
}

process_get_pid <- function(self, private) {
  if (private$exited) {
    private$pid
  } else {
    .Call(c_processx_get_pid, private$status)
  }
}
