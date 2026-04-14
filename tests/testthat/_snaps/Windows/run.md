# working directory does not exist

    Code
      run(px, wd = tempfile())
    Condition
      Error:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(c_processx_exec, command, c(command, args), pty, pty_options, ...` at initialize.R:162:<col>:
      ! create process '<path>/px' (system error 267, The directory name is invalid.
      ) @win/processx.c:1040 (processx_exec)

