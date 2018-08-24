## ----setup, include = FALSE----------------------------------------------
library(roxygen2)
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")

## ------------------------------------------------------------------------
library(processx)
px <- processx:::get_tool("px")
px

## ------------------------------------------------------------------------
pxhelp <- run(px, "--help")
cat(pxhelp$stderr)

## ------------------------------------------------------------------------
run(px, c("outln", "arg -   with spaces", "outln", "'arg with quote'"))

## ----error = TRUE--------------------------------------------------------
run(px, c("sleep", "5"), timeout = 1)

## ---- error = TRUE-------------------------------------------------------
run(px, c("return", "10"))

## ------------------------------------------------------------------------
outp <- run("ls", "..", echo = TRUE)

## ------------------------------------------------------------------------
run(px, c("getenv", "FOO"), env = c(Sys.getenv(), FOO = "bar"))

## ------------------------------------------------------------------------
proc <- process$new(px, c("sleep", "10"))
proc

## ------------------------------------------------------------------------
proc$get_name()
proc$get_cmdline()
proc$get_exe()
proc$is_alive()
proc$suspend()
proc$get_status()
proc$resume()
proc$get_status()
proc$kill()
proc$is_alive()
proc$get_exit_status()

## ------------------------------------------------------------------------
proc <- process$new(px, c("sleep", "1", "outln", "foo", "sleep", "1",
     "errln", "bar", "sleep", "1"), stdout = "|", "stderr" = "|")
proc$poll_io(-1)
proc$read_output_lines()
proc$poll_io(-1)
proc$read_error_lines()
proc$poll_io(-1)
proc$is_alive()

## ------------------------------------------------------------------------
proc1 <- process$new(px, c("sleep", "0.5", "outln", "foo1", "sleep", "1"),
     stdout = "|", "stderr" = "|")
proc2 <- process$new(px, c("sleep", "1", "outln", "foo2", "sleep", "1"),
     stdout = "|", "stderr" = "|")
poll(list(proc1, proc2), -1)
proc1$read_output_lines()
poll(list(proc1, proc2), -1)
proc2$read_output_lines()

## ------------------------------------------------------------------------
start_program <- function(command, args, message, timeout = 5, ...) {
  timeout <- as.difftime(timeout, units = "secs")
  deadline <- Sys.time() + timeout
  px <- process$new(command, args, stdout = "|", ...)
  while (px$is_alive() && (now <- Sys.time()) < deadline) {
    poll_time <- as.double(deadline - now, units = "secs") * 1000
    px$poll_io(as.integer(poll_time))
    lines <- px$read_output_lines()
    if (any(grepl(message, lines))) return(px)
  }

  px$kill()
  stop("Cannot start ", command)
}

## ------------------------------------------------------------------------
proc <- process$new(px, c("sleep", "3"))
ps <- proc$as_ps_handle()
ps::ps_memory_info(ps)

