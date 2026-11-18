# read_output_lines() fails for pty

    Code
      p$read_output_lines()
    Condition
      Error in `process_read_output_lines()`:
      ! ! Cannot read lines from a pty (see manual)

# pty = TRUE argument errors

    Code
      process$new(px, c("return", "0"), pty = TRUE, stdin = "|")
    Condition
      Error in `process_initialize()`:
      ! ! `stdin` must be `NULL` if `pty == TRUE`
    Code
      process$new(px, c("return", "0"), pty = TRUE, stdout = "|")
    Condition
      Error in `process_initialize()`:
      ! ! `stdout` must be `NULL` if `pty == TRUE`
    Code
      process$new(px, c("return", "0"), pty = TRUE, stderr = "|")
    Condition
      Error in `process_initialize()`:
      ! ! `stderr` must be `NULL` if `pty == TRUE`
    Code
      process$new(px, c("return", "0"), pty = TRUE, pty_options = list(echo = NULL))
    Condition
      Error in `process_initialize()`:
      ! ! Uknown pty option(s): `echo`

