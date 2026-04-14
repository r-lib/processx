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

