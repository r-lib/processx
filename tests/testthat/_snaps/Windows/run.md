# working directory does not exist

    Code
      run(px, wd = tempfile())
    Condition
      Error:
      ! Native call to `processx_exec` failed
      Caused by error:
      ! create process '<path>/px' (system error 267, The directory name is invalid.
      ) @win/processx.c:1040 (processx_exec)

