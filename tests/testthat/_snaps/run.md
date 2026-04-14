# binary=TRUE errors with line callbacks

    Code
      run(px, "out", encoding = "binary", stdout_line_callback = function(x, ...) x)
    Condition
      Error:
      ! ! `stdout_line_callback` cannot be used with `encoding = "binary"`

---

    Code
      run(px, "out", encoding = "binary", stderr_line_callback = function(x, ...) x)
    Condition
      Error:
      ! ! `stderr_line_callback` cannot be used with `encoding = "binary"`

# pty=TRUE errors on incompatible arguments

    Code
      run("echo", pty = TRUE, stdout = NULL)
    Condition
      Error:
      ! ! `stdout` must be `"|"` (the default) if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr = NULL)
    Condition
      Error:
      ! ! `stderr` must be `"|"` (the default) if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_to_stdout = TRUE)
    Condition
      Error:
      ! ! `stderr_to_stdout` must be `FALSE` if `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_callback = function(x, ...) x)
    Condition
      Error:
      ! ! `stderr_callback` cannot be used with `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stderr_line_callback = function(x, ...) x)
    Condition
      Error:
      ! ! `stderr_line_callback` cannot be used with `pty = TRUE`

---

    Code
      run("echo", pty = TRUE, stdin = "|")
    Condition
      Error:
      ! ! When `pty = TRUE`, `stdin` must be `NULL` or a file path

