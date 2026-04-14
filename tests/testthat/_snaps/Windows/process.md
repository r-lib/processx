# non existing process

    Code
      process$new(tempfile())
    Condition
      Error:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(c_processx_exec, command, c(command, args), pty, pty_options, ...` at initialize.R:<line>:<col>:
      ! Command '<tempdir>/<tempfile>' not found @win/processx.c:1017 (processx_exec)

# working directory does not exist

    Code
      process$new(px, wd = tempfile())
    Condition
      Error:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(c_processx_exec, command, c(command, args), pty, pty_options, ...` at initialize.R:<line>:<col>:
      ! create process '<path>/px' (system error 267, The directory name is invalid.
      ) @win/processx.c:1262 (processx_exec)

