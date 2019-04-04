
#' Start a process
#'
#' @param self this
#' @param private this$private
#' @param command Command to run, string scalar.
#' @param args Command arguments, character vector.
#' @param stdin Standard input, NULL to ignore.
#' @param stdout Standard output, NULL to ignore, TRUE for temp file.
#' @param stderr Standard error, NULL to ignore, TRUE for temp file.
#' @param connections Connections to inherit in the child process.
#' @param poll_connection Whether to create a connection for polling.
#' @param env Environment vaiables.
#' @param cleanup Kill on GC?
#' @param cleanup_tree Kill process tree on GC?
#' @param wd working directory (or NULL)
#' @param echo_cmd Echo command before starting it?
#' @param supervise Should the process be supervised?
#' @param encoding Assumed stdout and stderr encoding.
#' @param post_process Post processing function.
#'
#' @keywords internal

process_initialize <- function(self, private, command, args,
                               stdin, stdout, stderr, connections,
                               poll_connection, env, cleanup, cleanup_tree,
                               wd, echo_cmd, supervise,
                               windows_verbatim_args, windows_hide_window,
                               encoding, post_process) {

  "!DEBUG process_initialize `command`"

  assert_that(
    is_string(command),
    is.character(args),
    is_string_or_null(stdin),
    is_string_or_null(stdout),
    is_string_or_null(stderr),
    is_connection_list(connections),
    is.null(poll_connection) || is_flag(poll_connection),
    is.null(env) || is_named_character(env),
    is_flag(cleanup),
    is_flag(cleanup_tree),
    is_string_or_null(wd),
    is_flag(echo_cmd),
    is_flag(windows_verbatim_args),
    is_flag(windows_hide_window),
    is_string(encoding),
    is.function(post_process) || is.null(post_process))

  if (cleanup_tree && !cleanup) {
    warning("`cleanup_tree` overrides `cleanup`, and process will be ",
            "killed on GC")
    cleanup <- TRUE
  }

  private$command <- command
  private$args <- args
  private$cleanup <- cleanup
  private$cleanup_tree <- cleanup_tree
  private$wd <- wd
  private$pstdin <- stdin
  private$pstdout <- stdout
  private$pstderr <- stderr
  private$connections <- connections
  private$env <- env
  private$echo_cmd <- echo_cmd
  private$windows_verbatim_args <- windows_verbatim_args
  private$windows_hide_window <- windows_hide_window
  private$encoding <- encoding
  private$post_process <- post_process

  poll_connection <- poll_connection %||%
    (!identical(stdout, "|") && !identical(stderr, "|") &&
     !length(connections))
  if (poll_connection) {
    pipe <- conn_create_pipepair()
    connections <- c(connections, list(pipe[[2]]))
    private$poll_pipe <- pipe[[1]]
  }

  if (echo_cmd) do_echo_cmd(command, args)

  if (!is.null(env)) env <- enc2utf8(paste(names(env), sep = "=", env))

  private$tree_id <- get_id()

  "!DEBUG process_initialize exec()"
  if (!is.null(wd)) {
    wd <- normalizePath(wd, winslash = "\\", mustWork = FALSE)
  }
  private$status <- .Call(
    c_processx_exec,
    command, c(command, args), stdin, stdout, stderr, connections, env,
    windows_verbatim_args, windows_hide_window,
    private, cleanup, wd, encoding,
    paste0("PROCESSX_", private$tree_id, "=YES")
  )

  ## We try the query the start time according to the OS, because we can
  ## use the (pid, start time) pair as an id when performing operations on
  ## the process, e.g. sending signals. This is only implemented on Linux,
  ## macOS and Windows and on other OSes it returns 0.0, so we just use the
  ## current time instead. (In the C process handle, there will be 0,
  ## still.)
  private$starttime <- .Call(c_processx__proc_start_time, private$status)
  if (private$starttime == 0) private$starttime <- Sys.time()

  ## Need to close this, otherwise the child's end of the pipe
  ## will not be closed when the child exits, and then we cannot
  ## poll it.
  if (poll_connection) close(pipe[[2]])

  if (is.character(stdin) && stdin != "|")
    stdin <- full_path(stdin)
  if (is.character(stdout) && stdout != "|")
    stdout <- full_path(stdout)
  if (is.character(stderr) && stderr != "|")
    stderr <- full_path(stderr)

  ## Store the output and error files, we'll open them later if needed
  private$stdin  <- stdin
  private$stdout <- stdout
  private$stderr <- stderr

  if (supervise) {
    supervisor_watch_pid(self$get_pid())
    private$supervised <- TRUE
  }

  invisible(self)
}
