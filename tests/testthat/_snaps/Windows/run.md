# working directory does not exist

    Code
      run(px, wd = tempfile())
    Condition
      Error in `process_initialize()`:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(...)` at initialize.R:<line>:<col>:
      ! create process '<path>/px' (system error 267, The directory name is invalid.
      ) @win/processx.c:1372 (processx_exec)

