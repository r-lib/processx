# Output and error are discarded by default

    Code
      p$read_output_lines(n = 1)
    Condition
      Error:
      ! stdout is not a pipe.
    Code
      p$read_all_output_lines()
    Condition
      Error:
      ! stdout is not a pipe.
    Code
      p$read_all_output()
    Condition
      Error:
      ! stdout is not a pipe.
    Code
      p$read_error_lines(n = 1)
    Condition
      Error:
      ! stderr is not a pipe.
    Code
      p$read_all_error_lines()
    Condition
      Error:
      ! stderr is not a pipe.
    Code
      p$read_all_error()
    Condition
      Error:
      ! stderr is not a pipe.

# same pipe

    Code
      p$read_all_error_lines()
    Condition
      Error:
      ! stderr is not a pipe.

# same file

    Code
      p$read_all_output_lines()
    Condition
      Error:
      ! stdout is not a pipe.

---

    Code
      p$read_all_error_lines()
    Condition
      Error:
      ! stderr is not a pipe.

# same NULL, for completeness

    Code
      p$read_all_output_lines()
    Condition
      Error:
      ! stdout is not a pipe.

---

    Code
      p$read_all_error_lines()
    Condition
      Error:
      ! stderr is not a pipe.

