
make_rstudio_script <- function(fifo, command, progress) {
  # TODO: get exit status somehow
  # TODO: ability to add an exit hook
  script <- rstudio_script_code(fifo, command, progress)
  script_file <- tempfile("px_rs_sc_", fileext = ".R")
  cat(deparse(script), file = script_file, sep = "\n")
  script_file
}

rstudio_script_code <- function(fifo, command, progress) {
  if (progress) {
    rstudio_script_code_progress(fifo, command)
  } else {
    rstudio_script_code_noprogress(fifo, command)
  }
}

rstudio_script_code_progress <- function(fifo, command) {
  substitute({
    conn <- processx::conn_create_file(fifo)

    cl <- call("executeCommand", commandId = "activateConsole", quiet = TRUE)
    cl[[1L]] <- call("::", as.name("rstudioapi"), cl[[1L]])
    try(rstudioapi:::callRemote(cl, environment()), silent = TRUE)

    #    try <- function(...) list(...)

    jobid <- NULL
    repeat {
      out <- processx::conn_read_lines(conn)
      cmd <- grep("^# ---- ", out)
      if (length(cmd)) {
        if (is.null(jobid)) {
          cl <- call("jobAdd", name = command, running = TRUE,
                     progressUnits = 100L, autoRemove = TRUE, show = FALSE)
          cl[[1L]] <- call("::", as.name("rstudioapi"), cl[[1L]])
          try(jobid <- rstudioapi:::callRemote(cl, environment()), silent = TRUE)
        }
        for (cmd1 in out[cmd]) {
          cmd1 <- scan(
            text = sub("^# ---- ", "", cmd1),
            what = "",
            quiet = TRUE
          )
          if (length(cmd1) == 3 && cmd1[2] == "progress") {
            pct <- as.numeric(sub("%", "", cmd1[3]))
            if (is.na(pct)) next
            cl <- call("jobSetProgress", jobid, pct)
            cl[[1L]] <- call("::", as.name("rstudioapi"), cl[[1L]])
            try(rstudioapi:::callRemote(cl, environment()), silent = TRUE)
          }
         }
        out <- out[-cmd]
      }
      cat(out, sep = "\n")
      if (!processx::conn_is_incomplete(conn)) break
    }
    cl <- call("jobRemove", jobid)
    cl[[1L]] <- call("::", as.name("rstudioapi"), cl[[1L]])
    try(rstudioapi:::callRemote(cl, environment()), silent = TRUE)
  }, list(fifo = fifo, command = command))
}

rstudio_script_code_noprogress <- function(fifo, command) {
  substitute({
    conn <- processx::conn_create_file(fifo)

    cl <- call("executeCommand", commandId = "activateConsole", quiet = TRUE)
    cl[[1L]] <- call("::", as.name("rstudioapi"), cl[[1L]])
    try(rstudioapi:::callRemote(cl, environment()), silent = TRUE)

    #    try <- function(...) list(...)

    repeat {
      out <- processx::conn_read_lines(conn)
      out <- grep("^# ---- ", out, value = TRUE, invert = TRUE)
      cat(out, sep = "\n")
      if (!processx::conn_is_incomplete(conn)) break
    }
  }, list(fifo = fifo, command = command))
}
