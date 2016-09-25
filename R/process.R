
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
#'                  stdout = TRUE, stderr = TRUE, cleanup = TRUE)
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
#'   \item{cleanup}{Whether to kill the process if the \code{process}
#'     object is garbage collected.}
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
      commandline = NULL, stdout = TRUE, stderr = TRUE, cleanup = TRUE)
      process_initialize(self, private, command, args, commandline,
                         stdout, stderr, cleanup),

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
    pipepid = NULL,       # Process of the pipe itself
    pid = NULL,           # The pid(s) of the child(ren) created by pipe()
    command = NULL,       # Save 'command' argument here
    args = NULL,          # Save 'args' argument here
    commandline = NULL,   # The full command line
    cleanup = NULL,       # cleanup argument
    stdout = NULL,        # stdout argument or stream
    stderr = NULL,        # stderr argument or stream
    pstdout = NULL,       # the original stdout argument
    pstderr = NULL,       # the original stderr argument
    cleanfiles = NULL,    # which temp stdout/stderr file(s) to clean up
    closed = NULL,        # Was the pipe closed already
    status = NULL,        # Exit status of the process
    starttime = NULL,     # timestamp of start

    get_short_name = function()
      process_get_short_name(self, private)
  )
)

## We just list all children of the R process here, and will select the
## proper one in the next function

get_my_pid_code <- function() {
  if (os_type() == "unix") {
    'ps -p $$ -o ppid=\necho $$\n'
  } else {
    paste0(
      "wmic process where '(parentprocessid=", Sys.getpid(),
      ")' get commandline, processid\n"
    )
  }
}

## On windows, we read until the process with the proper random id
## is listed. This will be the pipe process. Then we get its child,
## this will be the process that runs our script.

#' @importFrom utils tail

get_pid_from_file <- function(inp, cmdfile) {
  "!DEBUG get_pid_from_file"
  if (os_type() == "unix") {
    pids <- as.numeric(readLines(inp, n = 2))
    ## This should not happen, but just to be sure that we do not
    ## kill the R process itself
    setdiff(pids, Sys.getpid())

  } else {
    token <- basename(cmdfile)
    while (length(l <- readLines(inp, n = 1)) &&
      !grepl(token, l, fixed = TRUE)) {
      NULL
    }

    id <- if (length(l)) {
      as.numeric(tail(strsplit(str_trim(l), " ")[[1]], 1))
    }
    if (is.null(id) || is.na(id)) {
      stop("Cannot find pid, internal processx error")
    }
    c(id, get_children(id))
  }
}

#' Start a process
#'
#' @param self this
#' @param private this$private
#' @param command Command to run, string scalar.
#' @param args Command arguments, character vector.
#' @param commandline Alternative to command + args.
#' @param stdout Standard output, FALSE to ignore, TRUE for temp file.
#' @param stderr Standard error, FALSE to ignore, TRUE for temp file.
#' @param cleanup Kill on GC?
#'
#' @keywords internal
#' @importFrom utils head tail

process_initialize <- function(self, private, command, args,
                               commandline, stdout, stderr, cleanup) {

  "!DEBUG process_initialize"

  assert_string_or_null(command)
  assert_character(args)
  assert_flag_or_string(stdout)
  assert_flag_or_string(stderr)
  assert_string_or_null(commandline)
  assert_flag(cleanup)

  if (is.null(command) + is.null(commandline) != 1) {
    stop("Need exactly one of 'command' and 'commandline")
  }
  if (!is.null(commandline) && ! identical(args, character())) {
    stop("Omit 'args' when 'commandline' is specified")
  }

  private$command <- command
  private$args <- args
  private$commandline <- commandline
  private$cleanup <- cleanup
  private$closed <- FALSE
  private$pstdout <- stdout
  private$pstderr <- stderr

  if (isTRUE(stdout)) {
    private$cleanfiles <- c(private$cleanfiles, stdout <- tempfile())
  }
  if (isTRUE(stderr)) {
    private$cleanfiles <- c(private$cleanfiles, stderr <- tempfile())
  }

  cmd <- if (!is.null(command)) {
    paste0(
      shQuote(command), " ",
      if (length(args)) paste(shQuote(args), collapse = " ")
    )

  } else {
    paste0("(", commandline, ")")
  }

  fullcmd <- paste0(
    get_my_pid_code(),
    cmd, " ",
    " >",  if (isFALSE(stdout)) null_file() else shQuote(stdout),
    " 2>", if (isFALSE(stderr)) null_file() else shQuote(stderr),
    "\n"
  )

  ## Create temporary file to run
  ## Do NOT remove this with on.exit(), because that creates a race
  ## condition that hits back at you on Windows: the shell might not
  ## start running before the file is deleted by on.exit.
  cmdfile <- tempfile(fileext = ".bat")

  ## Add command to it, make it executable
  cat(fullcmd, file = cmdfile)
  Sys.chmod(cmdfile, "700")

  ## Start, we drop the output from the shell itself, for now
  ## We wrap the pipe() into process_connection, so it will be closed
  ## automatially. This way we do not need a finializer for the
  ## process object itself.
  "!DEBUG process_initialize pipe()"
  private$pipe <- process_connection(pipe(
    paste(shQuote(cmdfile), "2>&1"),
    open = "r"
  ))
  "!DEBUG process_initialize get_pid_from_file()"
  pids <- get_pid_from_file(private$pipe, cmdfile)
  private$pipepid <- head(pids, 1)
  private$pid <- tail(pids, -1)

  ## Cleanup on GC, if requested
  if (cleanup) {
    reg.finalizer(
      self,
      function(e) { "!DEBUG killing"; e$kill() },
      TRUE
    )
  }

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  invisible(self)
}

process_is_alive <- function(self, private) {
  "!DEBUG process_is_alive"
  if (is.null(private$pid)) {
    FALSE

  } else if (os_type() == "unix") {
    ! pskill(private$pid, signal = 0)

  } else {
    cmd <- paste0(
      "wmic process where (processid=",
      tail(private$pid, 1),
      ") get processid, parentprocessid /format:list 2>&1"
    )
    wmic_out <- shell(cmd, intern = TRUE)
    procs <- parse_wmic_list(wmic_out)
    nrow(procs) > 0
  }
}

process_restart <- function(self, private) {

  "!DEBUG process_restart"

  ## Suicide if still alive
  if (self$is_alive()) self$kill()

  ## Wipe out state, to be sure
  private$pid <- NULL
  private$pipepid <- NULL
  private$pipe <- NULL
  private$cleanfiles <- NULL
  private$closed <- NULL
  private$status <- NULL

  process_initialize(
    self,
    private,
    private$command,
    private$args,
    private$commandline,
    private$pstdout,
    private$pstderr,
    private$cleanup
  )

  invisible(self)
}

process_wait <- function(self, private) {
  "!DEBUG process_wait"
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
