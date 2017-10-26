
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
#' @param echo_cmd Echo command before starting it?
#' @param supervise Should the process be supervised?
#' @param encoding Assumed stdout and stderr encoding.
#'
#' @keywords internal
#' @importFrom utils head tail

process_initialize <- function(self, private, command, args,
                               commandline, stdout, stderr, cleanup,
                               echo_cmd, supervise, windows_verbatim_args,
                               windows_hide_window, encoding) {

  "!DEBUG process_initialize `command`"

  assert_that(is_string_or_null(command))
  assert_that(is.character(args))
  assert_that(is_string_or_null(stdout))
  assert_that(is_string_or_null(stderr))
  assert_that(is_string_or_null(commandline))
  assert_that(is_flag(cleanup))
  assert_that(is_flag(echo_cmd))
  assert_that(is_flag(windows_verbatim_args))
  assert_that(is_flag(windows_hide_window))
  assert_that(is_string(encoding))

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
  private$pstdout <- stdout
  private$pstderr <- stderr
  private$echo_cmd <- echo_cmd
  private$windows_verbatim_args <- windows_verbatim_args
  private$windows_hide_window <- windows_hide_window
  private$encoding <- encoding

  if (is.null(command)) {
    if (os_type() == "unix") {
      command <- "sh"
      args <- c("-c", commandline)
    } else {
      command <- "cmd"
      args <- c("/c", commandline)
    }
  }

  if (echo_cmd) do_echo_cmd(command, args)

  "!DEBUG process_initialize exec()"
  private$status <- .Call(
    c_processx_exec,
    command, c(command, args), stdout, stderr,
    windows_verbatim_args, windows_hide_window,
    private, cleanup, encoding
  )
  private$starttime <- Sys.time()

  if (is.character(stdout) && stdout != "|")
    stdout <- full_path(stdout)
  if (is.character(stderr) && stderr != "|")
    stderr <- full_path(stderr)

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  if (supervise) {
    supervisor_watch_pid(self$get_pid())
    private$supervised <- TRUE
  }

  invisible(self)
}
