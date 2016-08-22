
#' External process
#'
#' Managing external processes from R is not trivial, and this
#' class aims to help with this deficiency. It is essentially a small
#' wrapper around the \code{system} base R function, to return the process
#' id of the started process. This id is then used to manage the process.
#'
#' @section Usage:
#' \preformatted{p <- process$new(command, args)
#' p$is_alive()
#' p$kill(grace = 0.1)
#' p$restart()}
#'
#' @section Arguments:
#' \describe{
#'   \item{command}{Character scalar, the command to run.}
#'   \item{args}{Character vector, arguments to the command. No additional
#'     escaping is performed, so if you need to escape arguments,
#'     consider using \code{\link[base]{shQuote}}.}
#'   \item{grace}{Grace pediod between the TERM and KILL signals, in
#'     seconds.}
#' }
#'
#' @section Details:
#' \code{$new()} starts a new process. The arguments are passed to
#' \code{\link[base]{system2}}. R does \emph{not} wait for the process
#' to finish, but returns immediately.
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
#' \code{$restart()} restarts a process. It returns the process itself.
#'
#' @importFrom R6 R6Class
#' @name process
#' @examples
#' p <- process$new("sleep", "2")
#' p$is_alive()
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

    initialize = function(command, args = character(),
      stdout = FALSE, stderr = FALSE)
      process_initialize(self, private, command, args, stdout, stderr),

    kill = function(grace = 0.1)
      process_kill(self, private, grace),

    is_alive = function()
      process_is_alive(self, private),

    restart = function()
      process_restart(self, private),

    ## Output

    read_output_lines = function(...)
      process_read_output_lines(self, private, ...),

    read_error_lines = function(...)
      process_read_error_lines(self, private, ...),

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
    name = NULL,          # Name of the temporary file
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    cleanup = NULL        # which temp stdout/stderr file(s) to clean up
  )
)

#' Start a process
#'
#' @param self this
#' @param private this$private
#' @param command Command to run, string scalar.
#' @param args Command arguments, character vector.
#' @param stdout Standard output, FALSE to ignore, TRUE for temp file.
#' @param stderr Standard error, FALSE to ignore, TRUE for temp file.
#'
#' @keywords internal

process_initialize <- function(self, private, command, args,
                               stdout, stderr) {

  assert_string(command)
  assert_character(args)
  assert_flag_or_string(stdout)
  assert_flag_or_string(stderr)

  private$command <- command
  private$args <- args

  ## Destructor. This will be easier once https://github.com/wch/R6/pull/93
  ## is merged and published on CRAN.
  reg.finalizer(
    self,
    function(me) {
      me$kill()
      files <- me$.__enclos_env__$private$cleanup
      if (length(files)) suppressWarnings(file.remove())
    }
  )

  if (isTRUE(stdout)) {
    private$cleanup <- c(private$cleanup, stdout <- tempfile())
  }
  if (isTRUE(stderr)) {
    private$cleanup <- c(private$cleanup, stderr <- tempfile())
  }

  commandline <- paste(
    shQuote(command),
    ">",  if (isFALSE(stdout)) null_file() else shQuote(stdout),
    "2>", if (isFALSE(stderr)) null_file() else shQuote(stderr)
  )

  ## Create temporary file to run
  cmdfile <- tempfile(fileext = ".sh")
  on.exit(unlink(cmdfile), add = TRUE)

  ## Add command to it, make it executable
  cat(commandline, args, "\n", file = cmdfile)
  Sys.chmod(cmdfile, "700")

  ## Start
  private$pipe <- pipe(shQuote(cmdfile), open = "r")

  ## pid of the newborn, will be NULL if finished already
  private$name <- basename(cmdfile)
  private$pid <- get_pid(private$name)

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  invisible(self)
}

#' Kill a process
#'
#' @param self this
#' @param private this.private
#' @param grace Numeric scalar, grace period between sending a TERM
#'   and a KILL signal, in seconds.
#'
#' The process might not be running any more, but \code{tools::pskill}
#' does not seem to care about whether it could actually kill the
#' process or not. To be sure, that this workds on all platforms,
#' we put it in a `tryCatch()`
#'
#' A killed process can be restarted.
#'
#' @keywords internal
#' @importFrom tools pskill SIGKILL SIGTERM

process_kill <- function(self, private, grace) {
  if (! is.null(private$pid)) {
    safe_system("pkill", c("-15", "-P", private$pid))
    Sys.sleep(grace)
    safe_system("pkill", c("-9", "-P", private$pid))
    pskill(as.integer(private$pid), SIGTERM)
    Sys.sleep(grace)
    pskill(as.integer(private$pid), SIGTERM)
  }

  private$pid <- get_pid(private$name)

  invisible(self)
}

process_is_alive <- function(self, private) {
  private$pid <- get_pid(private$name)
  ! is.null(private$pid)
}

process_restart <- function(self, private) {

  ## Suicide if still alive
  if (self$is_alive()) self$kill()
  private$pid <- NULL

  process_initialize(self, private, private$command, private$args)

  invisible(self)
}
