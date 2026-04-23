# working directory does not exist

    Code
      run(px, wd = tempfile())
    Condition
      Error in `process_initialize()`:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(...)` at initialize.R:<line>:<col>:
      ! cannot start processx process '<path>/px' (system error 2, No such file or directory) @unix/processx.c:650 (processx_exec)

