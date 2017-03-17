
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
#'                  echo_cmd = FALSE, windows_verbatim_args = FALSE,
#'                  windows_hide_window = FALSE)
#'
#' p$is_alive()
#' p$signal(signal)
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
#'   \item{windows_verbatim_args}{Whether to omit quoting the arguments
#'     on Windows. It is ignored on other platforms.}
#'   \item{windows_hide_window}{Whether to hide the application's window
#'     on Windows. It is ignored on other platforms.}
#'   \item{grace}{Grace pediod between the TERM and KILL signals, in
#'     seconds.}
#'   \item{signal}{The signal to send to the process.}
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

    signal = function(signal)
      process_signal(self, private, signal),

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

    command = NULL,       # Save 'command' argument here
    args = NULL,          # Save 'args' argument here
    commandline = NULL,   # The full command line
    cleanup = NULL,       # cleanup argument
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    pstdout = NULL,       # the original stdout argument
    pstderr = NULL,       # the original stderr argument
    cleanfiles = NULL,    # which temp stdout/stderr file(s) to clean up
    status = list(NULL, NULL, NULL),
                          # Exit status, pid and handle. The exit status is
                          # NULL if we don't know it yet. handle might be
                          # NULL, before start and after finish. Exit status
                          # is negative signal if killed by a signal.
    starttime = NULL,     # timestamp of start
    statusfile = NULL,    # file for the exit status
    echo_cmd = NULL,      # whether to echo the command
    windows_verbatim_args = NULL,
    windows_hide_window = NULL,

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
  private$status <- list(NULL, NULL, NULL)

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

#' Process status (and related functions).
#'
#' @param self this
#' @param private private this
#'
#' @section UNIX:
#'
#' The main complication here, is that checking the status of the process
#' might mean that we need to collect its exit status.
#'
#' Collecting the exit status always means freeing memory allocated for
#' the handle.
#'
#' * `process_wait`:
#'     1. If we already have its exit status, return immediately.
#'     2. Otherwise, do a blocking `waitpid()`.
#'     3. When it's done, collect the exit status.
#' * `process_is_alive`:
#'     1. If we already have its exit status, then return `FALSE`.
#'     2. Otherwise, do a non-blocking `waitpid()`.
#'     3. If the `waitpid()` says that it is running, then return `TRUE`.
#'     4. Otherwise collect its exit status, and return `FALSE`.
#' * `process_get_exit_status`:
#'     1. If we already have the exit status, then return that.
#'     2. Otherwise do a non-blocking `waitpid()`.
#'     3. If the process just finished, then collect the exit status, and
#'        also return it.
#'     4. Otherwise return `NULL`, the process is still running.
#' * `process_signal`:
#'     1. If we already have its exit status, return with `FALSE`.
#'     2. Otherwise just try to deliver the signal. If successful, return
#'        `TRUE`, otherwise return `FALSE`.
#'
#'     We might as well call `waitpid()` as well, but `process_signal` is
#'     able to deliver arbitrary signals, so the process might not have
#'     finished.
#' * `process_kill`:
#'     1. Check if we have the exit status. If yes, then the process
#'        has already finished. and we return `FALSE`. We don't error,
#'        because then there would be no way to deliver a signal.
#'        (Simply doing `if (p$is_alive()) p$kill()` does not work, because
#'        it is a race condition.
#'     2. If there is no exit status, the process might be running (or might
#'        be a zombie).
#'     3. We call a non-blocking `waitpid()` on the process and potentially
#'        collect the exit status. If the process has exited, then we return
#'        TRUE. This step is to avoid the potential grace period, if the
#'        process is in a zombie state.
#'     4. If the process is still running, we call `kill(SIGKILL)`.
#'     5. We do a blocking `waitpid()` to collect the exit status.
#'     6. If the process was indeed killed by us, we return `TRUE`.
#'     7. Otherwise we return `FALSE`.
#'
#'    The return value of `process_kill()` is `TRUE` if the process was
#'    indeed killed by the signal. It is `FALSE` otherwise, i.e. if the
#'    process finished.
#'
#'    We currently ignore the grace argument, as there is no way to
#'    implement it on Unix. It will be implemented later using a SIGCHLD
#'    handler.
#'
#' * Finalizers:
#'
#'     Finalizers are called on the handle only, so we do not know if the
#'     process has already finished or not.
#'
#'     1. Call a non-blocking `waitpid()` to see if it is still running.
#'     2. If just finished, then collect exit status (=free memory).
#'     3. If it has finished before, then still try to free memory, just in
#'        case the exit status was read out by another package.
#'     4. If it is running, then kill it with SIGKILL, then call a blocking
#'        `waitpid()` to clean up the zombie process. Then free all memory.
#'
#'     The finalizer is implemented in C, because we might need to use it
#'     from the process startup code (which is C).
#'
#' @keywords internal
#' @seealso [process_kill()]

process_wait <- function(self, private) {
  "!DEBUG process_wait `private$get_short_name()`"
  private$status <- .Call("processx_wait", private$status)
  invisible(self)
}

#' @rdname process_wait

process_is_alive <- function(self, private) {
  "!DEBUG process_is_alive `private$get_short_name()`"
  private$status <- .Call("processx_is_alive", private$status)
  is.null(private$status[[1]])
}

#' @rdname process_wait

process_get_exit_status <- function(self, private) {
  "!DEBUG process_get_exit_status `private$get_short_name()`"
  private$status <- .Call("processx_get_exit_status", private$status)
  ## This is NULL if still running
  private$status[[1]]
}

#' @rdname process_wait

process_signal <- function(self, private, signal) {
 "!DEBUG process_signal `private$get_short_name()` `signal`"
 .Call("processx_signal", private$status, as.integer(signal))
}

#' @rdname process_wait

process_kill <- function(self, private, grace) {
  "!DEBUG process_kill '`private$get_short_name()`', pid `private$get_pid()`"
  res <- .Call("processx_kill", private$status, as.numeric(grace))
  private$status <- res[[1]]
  res[[2]]
}

process_get_start_time <- function(self, private) {
  private$starttime
}

process_get_pid <- function(self, private) {
  private$status[[2]]
}
