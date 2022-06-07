# simple error

    Code
      cat(out$stderr)
    Output
      Error in `f()`:
      This failed
      ---
      Backtrace:
      1. global f()
      2. processx:::throw("This failed")
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `f()`:
      This failed
      Type .Last.error to see the more details.

