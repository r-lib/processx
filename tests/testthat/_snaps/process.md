# non existing process

    Code
      process$new(tempfile())
    Condition
      Error:
      ! Native call to `processx_exec` failed
      Caused by error:
      ! cannot start processx process '<tempdir>/<tempfile>' (system error 2, No such file or directory) @unix/processx.c:613 (processx_exec)

# post processing

    Code
      p$get_result()
    Condition
      Error:
      ! Process is still alive

# working directory does not exist

    Code
      process$new(px, wd = tempfile())
    Condition
      Error:
      ! Native call to `processx_exec` failed
      Caused by error:
      ! cannot start processx process '<path>/px' (system error 2, No such file or directory) @unix/processx.c:613 (processx_exec)

