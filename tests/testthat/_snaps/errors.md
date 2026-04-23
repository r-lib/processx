# output from error

    Code
      cat(out$stderr)
    Output
      Error in `processx::run(...)` at script.R:2:5:
      ! System command 'px' failed
      ---
      Exit status: 100
      Stderr:
      1
      2
      3
      4
      5
      6
      7
      8
      9
      10
      11
      12
      13
      14
      15
      16
      17
      18
      19
      20
      ---
      Backtrace:
      1. base::source("script.R")
      2. | base::withVisible(eval(ei, envir))
      3. | base::eval(ei, envir)
      4. | base::eval(ei, envir)
      5. processx::run(...) at script.R:2:5
      6. processx:::throw(...)
      Execution halted

