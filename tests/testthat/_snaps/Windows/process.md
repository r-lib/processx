# non existing process

    Code
      process$new(tempfile())
    Condition
      Error:
      ! Native call to `processx_exec` failed
      Caused by error:
      ! Command '<tempdir>/<tempfile>' not found @win/processx.c:982 (processx_exec)

# working directory does not exist

    Code
      process$new(px, wd = tempfile())
    Condition
      Error:
      ! Native call to `processx_exec` failed
      Caused by error:
      ! create process '<path>/px' (system error 267, The directory name is invalid.
      ) @win/processx.c:1040 (processx_exec)

