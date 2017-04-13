# Stores information about the supervisor process
supervisor_info <- new.env()

reg.finalizer(supervisor_info, function(s) {
  # Call the functions on s directly, in case the GC event happens _after_ a new
  # `processx:::supervisor_info` has been created and the name `supervisor_info`
  # is bound to the new object.
  supervisor_kill(s)
}, onexit = TRUE)


# This takes an object s, because a new `supervisor_info` object could have been
# created.
supervisor_kill <- function(s = supervisor_info) {
  if (is.null(s$pid))
    return()

  if (!is.null(s$stdin) && is_pipe_open(s$stdin)) {
    write_lines_named_pipe(s$stdin, "kill")
  }

  if (!is.null(s$stdin) && is_pipe_open(s$stdin)) {
    close_named_pipe(s$stdin)
  }
  if (!is.null(s$stdout) && is_pipe_open(s$stdout)) {
    close_named_pipe(s$stdout)
  }

  s$pid <- NULL
}


supervisor_reset <- function() {
  if (supervisor_running()) {
    supervisor_kill()
  }

  supervisor_info$pid         <- NULL
  supervisor_info$stdin       <- NULL
  supervisor_info$stdout      <- NULL
  supervisor_info$stdin_file  <- NULL
  supervisor_info$stdout_file <- NULL
}


supervisor_ensure_running <- function() {
  if (!supervisor_running())
    supervisor_start()
}


supervisor_running <- function() {
  if (is.null(supervisor_info$pid)) {
    FALSE
  } else {
    TRUE
  }
}


# Tell the supervisor to watch a PID
supervisor_watch_pid <- function(pid) {
  supervisor_ensure_running()
  write_lines_named_pipe(supervisor_info$stdin, as.character(pid))
}


# Start the supervisor process. Information about the process will be stored in
# supervisor_info. If startup fails, this function will throw an error.
supervisor_start <- function() {

  supervisor_info$stdin_file  <- named_pipe_tempfile("supervisor_stdin")
  supervisor_info$stdout_file <- named_pipe_tempfile("supervisor_stdout")

  supervisor_info$stdin  <- create_named_pipe(supervisor_info$stdin_file)
  supervisor_info$stdout <- create_named_pipe(supervisor_info$stdout_file)

  # Start the supervisor, passing the R process's PID to it.
  if (is_windows()) {
    # TODO: fix stdout
    p <- process$new(
      supervisor_path(),
      args   = c("-v", "-p", Sys.getpid(), "-i", supervisor_info$stdin_file),
      # stdout = supervisor_info$stdout_file,
      stdout = "supervisor_out.txt",
      cleanup = FALSE,
      commandline = NULL
    )

  } else {
    p <- process$new(
      supervisor_path(),
      args   = c("-p", Sys.getpid(), "-i", supervisor_info$stdin_file, "-v"),
      # stdout = supervisor_info$stdout_file,
      cleanup = FALSE,
      commandline = NULL
    )
  }

  if (!p$is_alive()) {
    stop("Error starting supervisor process.")
  }

  supervisor_info$pid <- NULL

  # Attempt to read the PID for 5 seconds
  t0 <- Sys.time()
  while (is.null(supervisor_info$pid)) {
    if (as.numeric(Sys.time() - t0, units = "secs") > 5) {
      stop("Timed out starting supervisor process.")
    }

    # pid_txt <- readLines(supervisor_info$stdout, n = 1)
    Sys.sleep(0.5)
    pid_txt <- "PID: 8888"

    if (length(pid_txt) > 0) {
      if (!grepl("^PID: \\d+$", pid_txt))
        stop("Incorrect format for supervisor PID output: \n", pid_txt)

      pid <- as.numeric(sub("^PID: ", "", pid_txt))

      if (is.na(pid))
        stop("Incorrect format for supervisor PID output: \n", pid_txt)

      supervisor_info$pid <- pid

    } else {
      Sys.sleep(0.2)
    }
  }
}


# Returns full path to the supervisor binary. Works when package is loaded the
# normal way, and when loaded with devtools::load_all().
supervisor_path <- function() {
  supervisor_name <- "supervisor"
  if (is_windows())
    supervisor_name <- paste0(supervisor_name, ".exe")

  # Detect if package was loaded via devtools::load_all()
  dev_meta <- parent.env(environment())$.__DEVTOOLS__
  devtools_loaded <- !is.null(dev_meta)

  if (devtools_loaded) {
    subdir <- file.path("src", "supervisor")
  } else {
    subdir <- "bin"
    # Add arch (it may be ""; on Windows it may be "/X64")
    subdir <- paste0(subdir, Sys.getenv("R_ARCH"))
  }

  system.file(subdir, supervisor_name, package = "processx", mustWork = TRUE)
}
