supervisor_info <- as.environment(
  # TODO: initialize in .onLoad. Make sure not to lose when package reloaded.
  list(
    pid         = NULL,
    stdin       = NULL,
    stdout      = NULL,
    stdin_file  = NULL,
    stdout_file = NULL
  )
)

supervisor_ensure_running <- function() {
  if (is.null(supervisor_info$pid))
    supervisor_start()

  # TODO: Deal with a killed supervisor. How?
}

supervisor_running <- function() {
  if (is.null(supervisor_info$pid)) {
    return(FALSE)
  }
}

supervisor_watch_pid <- function(pid) {
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

  supervisor_info$stdin  <- fifo(supervisor_info$stdin_file)
  supervisor_info$stdout <- fifo(supervisor_info$stdout_file)

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
