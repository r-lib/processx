# binary=TRUE errors with line callbacks

    Code
      run(px, "out", encoding = "binary", stdout_line_callback = function(x, ...) x)
    Condition
      Error in `run()`:
      ! ! `stdout_line_callback` cannot be used with `encoding = "binary"`

---

    Code
      run(px, "out", encoding = "binary", stderr_line_callback = function(x, ...) x)
    Condition
      Error in `run()`:
      ! ! `stderr_line_callback` cannot be used with `encoding = "binary"`

# pty=TRUE errors on incompatible arguments

    Code
      run("echo", pty = TRUE, stdout = NULL)
    Condition
      Error in `run()`:
      ! ! `stdout` must be `"|"` (the default) if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr = NULL)
    Condition
      Error in `run()`:
      ! ! `stderr` must be `"|"` (the default) if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_to_stdout = TRUE)
    Condition
      Error in `run()`:
      ! ! `stderr_to_stdout` must be `FALSE` if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_callback = function(x, ...) x)
    Condition
      Error in `run()`:
      ! ! `stderr_callback` cannot be used with `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_line_callback = function(x, ...) x)
    Condition
      Error in `run()`:
      ! ! `stderr_line_callback` cannot be used with `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stdin = "|")
    Condition
      Error in `run()`:
      ! ! When `pty = TRUE`, `stdin` must be `NULL` or a file path

