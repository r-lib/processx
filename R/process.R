
#' External process
#'
#' Managing external processes from R is not trivial, and this
#' class aims to help with this deficiency. It is essentially a small
#' wrapper around the \code{pipe} base R function, to return the process
#' id of the started process, and set its standard output and error
#' streams. The process id is then used to manage the process.
#'
#' @section Usage:
#' \preformatted{p <- process$new(command = NULL, args, commandline = NULL,
#'                  stdout = TRUE, stderr = TRUE)
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
#'   \item{args}{Character vector, arguments to the command. The will be
#'     escaped via \code{\link[base]{shQuote}}.}
#'   \item{commandline}{A character scalar, a full command line.
#'     No escaping will be performed on it.}
#'   \item{stdout}{What to do with the standard output. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file.}
#'   \item{stdout}{What to do with the standard error. Possible values:
#'     \code{FALSE}: discard it; a string, redirect it to this file,
#'     \code{TRUE}: redirect it to a temporary file.}
#'   \item{grace}{Grace pediod between the TERM and KILL signals, in
#'     seconds.}
#'   \item{...}{Extra arguments are passed to the
#'     \code{\link[base]{readLines}} function.}
#' }
#'
#' @section Details:
#' \code{$new()} starts a new process, it uses \code{\link[base]{pipe}}.
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
#'
NULL

#' @export

process <- R6Class(
  "process",
  public = list(

    initialize = function(command = NULL, args = character(),
      commandline = NULL, stdout = TRUE, stderr = TRUE)
      process_initialize(self, private, command, args, commandline,
                         stdout, stderr),

    kill = function(grace = 0.1)
      process_kill(self, private, grace),

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

    pipe = NULL,          # The pipe connection object
    pid = NULL,           # The pid(s) of the child(ren) created by pipe()
    command = NULL,       # Save 'command' argument here
    args = NULL,          # Save 'args' argument here
    commandline = NULL,   # The full command line
    name = NULL,          # Name of the temporary file
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    pstdout = NULL,       # the original stdout argument
    pstderr = NULL,       # the original stderr argument
    cleanup = NULL,       # which temp stdout/stderr file(s) to clean up
    closed = NULL,        # Was the pipe closed already
    status = NULL,        # Exit status of the process

    get_short_name = function()
      process_get_short_name(self, private)
  )
)

#' Start a process
#'
#' @param self this
#' @param private this$private
#' @param command Command to run, string scalar.
#' @param args Command arguments, character vector.
#' @param commandline Alternative to command + args.
#' @param stdout Standard output, FALSE to ignore, TRUE for temp file.
#' @param stderr Standard error, FALSE to ignore, TRUE for temp file.
#'
#' @keywords internal

process_initialize <- function(self, private, command, args,
                               commandline, stdout, stderr) {

  assert_string_or_null(command)
  assert_character(args)
  assert_flag_or_string(stdout)
  assert_flag_or_string(stderr)
  assert_string_or_null(commandline)

  if (is.null(command) + is.null(commandline) != 1) {
    stop("Need exactly one of 'command' and 'commandline")
  }
  if (!is.null(commandline) && ! identical(args, character())) {
    stop("Omit 'args' when 'commandline' is specified")
  }

  private$command <- command
  private$args <- args
  private$commandline <- commandline
  private$closed <- FALSE
  private$pstdout <- stdout
  private$pstderr <- stderr

  if (isTRUE(stdout)) {
    private$cleanup <- c(private$cleanup, stdout <- tempfile())
  }
  if (isTRUE(stderr)) {
    private$cleanup <- c(private$cleanup, stderr <- tempfile())
  }

  cmd <- if (!is.null(command)) {
    shQuote(command)
  } else {
    paste0("(", commandline, ")")
  }

  fullcmd <- paste(
    cmd,
    ">",  if (isFALSE(stdout)) null_file() else shQuote(stdout),
    "2>", if (isFALSE(stderr)) null_file() else shQuote(stderr)
  )

  ## Create temporary file to run
  cmdfile <- tempfile(fileext = ".bat")
  on.exit(unlink(cmdfile), add = TRUE)

  ## Add command to it, make it executable
  cat(fullcmd, if (length(args)) shQuote(args), "\n", file = cmdfile)
  Sys.chmod(cmdfile, "700")

  ## Start, we drop the output from the shell itself, for now
  ## We wrap the pipe() into process_connection, so it will be closed
  ## automatially. This way we do not need a finializer for the
  ## process object itself.
  private$pipe <- process_connection(pipe(
    paste(shQuote(cmdfile), ">", null_file(), "2>", null_file()),
    open = "r"
  ))

  ## pid of the newborn, will be NULL if finished already
  private$name <- basename(cmdfile)
  private$pid <- get_pid(private$name)

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  invisible(self)
}

process_is_alive <- function(self, private) {
  private$pid <- get_pid(private$name)
  ! is.null(private$pid)
}

process_restart <- function(self, private) {

  ## Suicide if still alive
  if (self$is_alive()) self$kill()

  ## Wipe out state, to be sure
  private$pid <- NULL
  private$pipe <- NULL
  private$pid <- NULL
  private$name <- NULL
  private$cleanup <- NULL
  private$closed <- NULL
  private$status <- NULL

  process_initialize(
    self,
    private,
    private$command,
    private$args,
    private$commandline,
    private$pstdout,
    private$pstderr
  )

  invisible(self)
}

process_wait <- function(self, private) {
  if (!private$closed) {
    ## windows does not wait on close (!), but it does on readLines
    readLines(private$pipe)
    private$status <- close(private$pipe)
    private$closed <- TRUE
  }
  invisible(self)
}

process_get_exit_status <- function(self, private) {
  private$status
}
