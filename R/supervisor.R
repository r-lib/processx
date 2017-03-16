# Stores information about the supervisor process
supervisor_info <- new.env()

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


reg.finalizer(supervisor_info, function(s) {
  # Call the functions on s directly, in case the GC event happens _after_ a new
  # `processx:::supervisor_info` has been created and the name `supervisor_info`
  # is bound to the new object.
  cat("Finalizing!\n")
  supervisor_kill(s)
}, onexit = TRUE)


# TODO: Add which_supervisor (borrow from Rttf2pt1)

supervisor_ensure_running <- function() {
  if (!supervisor_running())
    supervisor_start()

  # TODO: Deal with a killed supervisor. How?
}

supervisor_running <- function() {
  if (is.null(supervisor_info$pid)) {
    FALSE
  } else {
    TRUE
  }
}

# This takes an object s, because a new `supervisor_info` object could have been
# created.
supervisor_kill <- function(s = supervisor_info) {
  if (is.null(s$pid))
    return()

  if (!is.null(s$stdin) && is_fifo_open(s$stdin))
    writeLines("kill", s$stdin)

  if (!is.null(s$stdin) && is_fifo_open(s$stdin))
    close(s$stdin)
  if (!is.null(s$stdout) && is_fifo_open(s$stdout))
    close(s$stdout)

  s$pid <- NULL
}

supervisor_watch_pid <- function(pid) {
  supervisor_ensure_running()
  writeLines(as.character(pid), supervisor_info$stdin)
}

# TODO: Deal with session save/restart

# Start the supervisor process. Information about the process will be stored in
# supervisor_info. If startup fails, this function will throw an error.
supervisor_start <- function() {
  supervisor_name <- if (os_type() == "windows") "supervisor.exe" else "supervisor"
  supervisor_path <- system.file(supervisor_name, package = "processx",
    mustWork = TRUE)

  supervisor_info$stdin_file  <- tempfile("supervisor_stdin")
  supervisor_info$stdout_file <- tempfile("supervisor_stdout")

  supervisor_info$stdin  <- fifo(supervisor_info$stdin_file,  "w+")
  supervisor_info$stdout <- fifo(supervisor_info$stdout_file, "w+")

  # Start the supervisor, passing the R process's PID to it.
  res <- system2(
    supervisor_path,
    args   = Sys.getpid(),
    stdout = supervisor_info$stdout_file,
    stdin  = supervisor_info$stdin_file,
    wait   = FALSE
  )

  if (res != 0) {
    stop("Error starting supervisor process.")
  }

  supervisor_info$pid <- NULL

  # Attempt to read the PID for 5 seconds
  t0 <- Sys.time()
  while (is.null(supervisor_info$pid)) {
    if (as.numeric(Sys.time() - t0, units = "secs") > 5) {
      stop("Timed out starting supervisor process.")
    }

    pid_txt <- readLines(supervisor_info$stdout, n = 1)

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
