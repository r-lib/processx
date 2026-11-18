# pipeline input validation

    Code
      pipeline$new(list())
    Condition
      Error in `initialize()`:
      ! ! `cmds` must be a non-empty list of character vectors
    Code
      pipeline$new("ls")
    Condition
      Error in `initialize()`:
      ! ! `cmds` must be a non-empty list of character vectors
    Code
      pipeline$new(list("ls", character()))
    Condition
      Error in `initialize()`:
      ! ! `cmds[[2]]` must be a non-empty character vector
    Code
      pipeline$new(list("ls", 1))
    Condition
      Error in `initialize()`:
      ! ! `cmds[[2]]` must be a non-empty character vector

