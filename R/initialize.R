
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

  "!DEBUG process_initialize `command`"

  assert_that(is_string_or_null(command))
  assert_that(is.character(args))
  assert_that(is_flag_or_string(stdout))
  assert_that(is_flag_or_string(stderr))
  assert_that(is_string_or_null(commandline))
  assert_that(is_flag(cleanup))

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
    ## This is needed for "composite" commands: "cmd1 ; cmd2"
    paste("(", commandline, ")")
  }

  pidfile <- tempfile()
  private$statusfile <- tempfile()
  cmdfile <- create_cmd_file(cmd, pidfile, private$statusfile,
                             stdout, stderr)

  ## Clean up the pid files
  pidfile2 <- paste0(pidfile, "2")
  pidfile3 <- paste0(pidfile, "3")
  on.exit(
    {
      try(unlink(pidfile), silent = TRUE)
      try(unlink(pidfile2), silent = TRUE)
      try(unlink(pidfile3), silent = TRUE)
    },
    add = TRUE
  )

  "!DEBUG process_initialize system()"
  ret <- system(
    paste0(
      shQuote(cmdfile), " ",
      shQuote(basename(cmdfile)), " ",
      "2>", shQuote(tempfile()), " ",
      ">", shQuote(tempfile())
    ),
    wait = FALSE
  )
  if (ret != 0) stop("Cannot start process")

  ## Get the pid from the pid file, this also removes it
  pids <- get_pid_from_file(pidfile, cmdfile)
  private$pid <- head(pids, 1)
  "!DEBUG process_initialize get_pid_from_file(): `private$pid`"

  ## Cleanup on GC, if requested
  if (cleanup) {
    reg.finalizer(
      self,
      function(e) {
        "!DEBUG killing"
        e$kill()
      },
      TRUE
    )
  }

  ## Store the output and error files, we'll open them later if needed
  private$stdout <- stdout
  private$stderr <- stderr

  invisible(self)
}

## ---------------------------------------------------------------------

#' Platform-dependent code to output the PID to a file
#'
#' [get_pid_form_file()] will read the PID from the file.
#' You need this function, because the format of the file is
#' platform dependent.
#'
#' @param pidfile The file that will contain the pid
#'   `paste0(pidfile, "3")` will be used to notify that `pidfile`
#'   is complete and contains the PID. (Otherwise it might be an
#'   empty file.)
#' @return Numeric PID
#'
#' @family pid queries
#' @keywords internal

get_my_pid_code <- function(pidfile) {
  if (os_type() == "unix") {
    get_my_pid_code_unix(pidfile)
  } else {
    get_my_pid_code_windows(pidfile)
  }
}

#' Some tricks in the windows version:
#' * we output all child processes of the R session into the output
#'   file, and will use a random id, that is an argument to the R script,
#'   to extract the correct child.
#' * `wmic` outputs UTF-16 text to the file, so we run `type` in it, and
#'   redirect it to another file, which will be ASCII already.
#'
#' @rdname get_my_pid_code

get_my_pid_code_windows <- function(pidfile) {
  script <- paste0(
    "wmic /output:%s process where '(parentprocessid=%d)'",
    "  get commandline, processid\n",
    "type %s > %s\n",
    "echo done > %s\n"
  )
  pidfile2 <- paste0(pidfile, "2")
  pidfile3 <- paste0(pidfile, "3")
  sprintf(script, shQuote(pidfile2), Sys.getpid(),
          shQuote(pidfile2), shQuote(pidfile),
          shQuote(pidfile3))
}

#' The unix version is straightforward, as a unix shell knows its
#' process id.
#'
#' @rdname get_my_pid_code

get_my_pid_code_unix <- function(pidfile) {
  script <- paste0(
    "echo $$ > %s\n",
    "echo done > %s\n"
  )
  sprintf(script, shQuote(pidfile), shQuote(paste0(pidfile, "3")))
}

## ---------------------------------------------------------------------

#' Parse a PID from an output file written by [get_my_pid()]
#'
#' The format of the file is platform dependent.
#'
#' @param pidfile Name of the pid file, same as the argument to
#'   [get_my_pid_file()].
#' @param cmdfile Name of the script file, we use this as an ID on
#'   windows, to find the process among the children of the R process,
#'   because windows shells cannot report their own process id.
#'
#' @family pid queries
#' @keywords internal

get_pid_from_file <- function(pidfile, cmdfile) {
  "!DEBUG get_pid_from_file"
  if (os_type() == "unix") {
    get_pid_from_file_unix(pidfile, cmdfile)
  } else {
    get_pid_from_file_windows(pidfile, cmdfile)
  }
}

#' @rdname get_pid_from_file
#' @importFrom utils tail

get_pid_from_file_windows <- function(pidfile, cmdfile) {

  pidfile2 <- paste0(pidfile, "2")
  pidfile3 <- paste0(pidfile, "3")

  ## Wait for the 'done' file to be there, with a timeout
  wait_for_file(pidfile3)

  pidhandle <- file(pidfile, open = "r")
  on.exit(try(close(pidhandle), silent = TRUE), add = TRUE)

  token <- basename(cmdfile)
  while (length(l <- readLines(pidhandle, n = 1)) &&
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

#' @rdname get_pid_from_file

get_pid_from_file_unix <- function(pidfile, cmdfile) {
  ## Wait for the 'done' file to be there
  pidfile3 <- paste0(pidfile, "3")
  wait_for_file(pidfile3)

  pids <- as.numeric(readLines(pidfile, n = 1))

  ## This should not happen, but just to be sure that we do not
  ## kill the R process itself
  setdiff(pids, Sys.getpid())
}

## ---------------------------------------------------------------------

get_exit_status_code <- function(statusfile) {
  "!DEBUG get_exit_status_code"
  if (os_type() == "unix") {
    paste("echo $? >", shQuote(statusfile))
  } else {
    paste("echo %errorlevel% >", shQuote(statusfile))
  }
}

## ---------------------------------------------------------------------

create_cmd_file <- function(cmd, pidfile, statusfile, stdout, stderr) {
  if (os_type() == "unix") {
    create_cmd_file_unix(cmd, pidfile, statusfile, stdout, stderr)
  } else {
    create_cmd_file_windows(cmd, pidfile, statusfile, stdout, stderr)
  }
}

create_cmd_file_unix <- function(cmd, pidfile, statusfile, stdout,
                                 stderr) {

  fullcmd <- paste0(
    get_my_pid_code(pidfile),
    cmd, " ",
    " >",  if (isFALSE(stdout)) null_file() else shQuote(stdout),
    " 2>", if (isFALSE(stderr)) null_file() else shQuote(stderr),
    "\n",
    get_exit_status_code(statusfile)
  )

  ## Create temporary file to run
  ## Do NOT remove this with on.exit(), because that creates a race
  ## condition that hits back at you on Windows: the shell might not
  ## start running before the file is deleted by on.exit.
  cmdfile <- tempfile(fileext = ".bat")

  ## Add command to it, make it executable
  cat(fullcmd, file = cmdfile)
  Sys.chmod(cmdfile, "700")

  cmdfile
}

## On Windows, we need another file, because calling a batch
## file from another file does not give back the control,
## so we cannot extract the exit status. Using `cmd /c` or
## `call` did not work for me with the redirections.

create_cmd_file_windows <- function(cmd, pidfile, statusfile, stdout,
                                    stderr) {

  anotherfile <- tempfile(fileext = ".bat")
  Sys.chmod(anotherfile, "700")
  tmpcmd <- paste0(
    cmd,
    " >",  if (isFALSE(stdout)) null_file() else shQuote(stdout),
    " 2>", if (isFALSE(stderr)) null_file() else shQuote(stderr),
    "\n"
  )
  cat(tmpcmd, file = anotherfile)

  fullcmd <- paste0(
    get_my_pid_code(pidfile), "\n",
    "call ", shQuote(anotherfile), "\n",
    get_exit_status_code(statusfile), "\n"
  )

  cmdfile <- tempfile(fileext = ".bat")
  cat(fullcmd, file = cmdfile)
  Sys.chmod(cmdfile, "700")

  cmdfile
}
