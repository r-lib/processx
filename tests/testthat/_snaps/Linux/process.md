# non existing process

    Code
      process$new(tempfile())
    Condition
      Error:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(c_processx_exec, command, c(command, args), pty, pty_options, ...` at initialize.R:162:<col>:
      ! cannot start processx process '<tempdir>/<tempfile>' (system error 2, No such file or directory) @unix/processx.c:611 (processx_exec)

# working directory does not exist

    Code
      process$new(px, wd = tempfile())
    Condition
      Error:
      ! ! Native call to `processx_exec` failed
      Caused by error in `chain_call(c_processx_exec, command, c(command, args), pty, pty_options, ...` at initialize.R:162:<col>:
      ! cannot start processx process '<path>/px' (system error 2, No such file or directory) @unix/processx.c:611 (processx_exec)

