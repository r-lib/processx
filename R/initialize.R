
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
#'
#' @keywords internal
#' @importFrom utils head tail

process_initialize <- function(self, private, command, args,
                               commandline, stdout, stderr, cleanup,
                               echo_cmd) {

  "!DEBUG process_initialize `command`"

  assert_that(is_string_or_null(command))
  assert_that(is.character(args))
  assert_that(is_flag_or_string(stdout))
  assert_that(is_flag_or_string(stderr))
  assert_that(is_string_or_null(commandline))
  assert_that(is_flag(cleanup))
  assert_that(is_flag(echo_cmd))

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

  if (isTRUE(stdout)) {
    private$cleanfiles <- c(private$cleanfiles, stdout <- tempfile())
  }
  if (isTRUE(stderr)) {
    private$cleanfiles <- c(private$cleanfiles, stderr <- tempfile())
  }

  ## Make sure the files exist when the process object is created
  ## exec uses NULL instead of FALSE, easier to test in C
  if (isFALSE(stdout)) stdout <- NULL else cat("", file = stdout)
  if (isFALSE(stderr)) stderr <- NULL else cat("", file = stderr)

  if (is.null(command)) {
    command <- "sh"
    args <- c("-c", commandline)
  }

  if (echo_cmd) {
    cat("Running command", cmd, "\n")
    if (length(args)) cat("Arguments:", args, sep = "\n")
  }

  "!DEBUG process_initialize exec()"
  private$pid <- exec(command, args, stdout = stdout, stderr = stderr)
  private$starttime <- Sys.time()

  ## Cleanup on GC, if requested
  if (cleanup) {
    reg.finalizer(
      self,
      function(e) {
        "!DEBUG killing"
        pskill(private$pid)
        wait(private$pid)
      },
      TRUE
    )
  }

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  invisible(self)
}
