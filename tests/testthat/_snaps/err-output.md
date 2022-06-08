# simple error

    Code
      cat(out$stderr)
    Output
      Error in `f()` at script.R:3:5:
      ! This failed
      ---
      Backtrace:
      1. base::source("script.R")
      2. | base::withVisible(eval(ei, envir))
      3. | base::eval(ei, envir)
      4. | base::eval(ei, envir)
      5. global f() at script.R:3:5
      6. processx:::throw("This failed") at script.R:2:10
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `f()` at script.R:4:5:
      ! This failed
      Type .Last.error to see the more details.

# simple error with cli

    Code
      cat(out$stderr)
    Output
      Error in `f()` at script.R:4:5:
      ! This failed
      ---
      Backtrace:
      1. base::source("script.R")
      2. | base::withVisible(eval(ei, envir))
      3. | base::eval(ei, envir)
      4. | base::eval(ei, envir)
      5. global f() at script.R:4:5
      6. processx:::throw("This failed") at script.R:3:10
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `f()` at script.R:5:5:
      ! This failed
      Type .Last.error to see the more details.

# simple error with cli and colors

    Code
      cat(out$stderr)
    Output
      [1m[33mError[39m[22m in `f()`[90m at script.R:5:5[39m:
      [33m![39m This failed
      ---
      Backtrace:
      [90m1. [39mbase::[36msource[39m[33m("script.R")[39m
      [90m2. | base::withVisible(eval(ei, envir))[39m
      [90m3. | base::eval(ei, envir)[39m
      [90m4. | base::eval(ei, envir)[39m
      [90m5. [39mglobal [36mf[39m[33m()[39m[90m at script.R:5:5[39m
      [90m6. [39mprocessx:::[36mthrow[39m[33m("This failed")[39m[90m at script.R:4:10[39m
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      [1m[33mError[39m[22m in `f()`[90m at script.R:6:5[39m:
      [33m![39m This failed
      [90mType .Last.error to see the more details.[39m

# chain_error

    Code
      cat(out$stderr)
    Output
      Error in `do()` at script.R:14:10:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:10:9:
      ! something is wrong here
      Caused by error in `do3()` at script.R:7:9:
      ! because of this
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. global f() at script.R:15:5
       6. global g() at script.R:12:10
       7. global h() at script.R:13:10
       8. global do() at script.R:14:10
       9. processx:::chain_error(do2(), "Failed to base64 encode") at script.R:10:9
      10. | base::withCallingHandlers({
      11. global do2()
      12. processx:::chain_error(do3(), "something is wrong here") at script.R:7:9
      13. | base::withCallingHandlers({
      14. global do3()
      15. processx:::throw("because of this") at script.R:4:9
      16. | base::signalCondition(cond)
      17. | (function (e)
      18. | processx:::throw_error(err, parent = e)
      19. | base::signalCondition(cond)
      20. | (function (e)
      21. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `do()` at script.R:16:14:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:12:13:
      ! something is wrong here
      Caused by error in `do3()` at script.R:9:13:
      ! because of this
      Type .Last.error to see the more details.

---

    Code
      cat(out$stderr)
    Output
      Error in `do()` at script.R:16:14:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:12:13:
      ! something is wrong here
      Caused by error in `do3()` at script.R:9:13:
      ! because of this
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. global f() at script.R:17:9
       6. global g() at script.R:14:14
       7. global h() at script.R:15:14
       8. global do() at script.R:16:14
       9. processx:::chain_error(do2(), "Failed to base64 encode") at script.R:12:13
      10. | base::withCallingHandlers({ ...
      11. global do2()
      12. processx:::chain_error(do3(), "something is wrong here") at script.R:9:13
      13. | base::withCallingHandlers({ ...
      14. global do3()
      15. processx:::throw("because of this") at script.R:6:13
      16. | base::signalCondition(cond)
      17. | (function (e) ...
      18. | processx:::throw_error(err, parent = e)
      19. | base::signalCondition(cond)
      20. | (function (e) ...
      21. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stderr)
    Output
      [1m[33mError[39m[22m in `do()`[90m at script.R:19:14[39m:
      [33m![39m Failed to base64 encode
      [1mCaused by error[22m in `do2()`[90m at script.R:15:13[39m:
      [33m![39m something is wrong here
      [1mCaused by error[22m in `do3()`[90m at script.R:12:13[39m:
      [33m![39m because of this
      ---
      Backtrace:
      [90m 1. [39mbase::[36msource[39m[33m("script.R")[39m
      [90m 2. | base::withVisible(eval(ei, envir))[39m
      [90m 3. | base::eval(ei, envir)[39m
      [90m 4. | base::eval(ei, envir)[39m
      [90m 5. [39mglobal [36mf[39m[33m()[39m[90m at script.R:20:9[39m
      [90m 6. [39mglobal [36mg[39m[33m()[39m[90m at script.R:17:14[39m
      [90m 7. [39mglobal [36mh[39m[33m()[39m[90m at script.R:18:14[39m
      [90m 8. [39mglobal [36mdo[39m[33m()[39m[90m at script.R:19:14[39m
      [90m 9. [39mprocessx:::[36mchain_error[39m[33m([39m[36mdo2[39m[34m()[39m, [33m"Failed to base64 encode")[39m[90m at script.R:15:13[39m
      [90m10. | base::withCallingHandlers({ ...[39m
      [90m11. [39mglobal [36mdo2[39m[33m()[39m
      [90m12. [39mprocessx:::[36mchain_error[39m[33m([39m[36mdo3[39m[34m()[39m, [33m"something is wrong here")[39m[90m at script.R:12:13[39m
      [90m13. | base::withCallingHandlers({ ...[39m
      [90m14. [39mglobal [36mdo3[39m[33m()[39m
      [90m15. [39mprocessx:::[36mthrow[39m[33m("because of this")[39m[90m at script.R:9:13[39m
      [90m16. | base::signalCondition(cond)[39m
      [90m17. | (function (e) ...[39m
      [90m18. | processx:::throw_error(err, parent = e)[39m
      [90m19. | base::signalCondition(cond)[39m
      [90m20. | (function (e) ...[39m
      [90m21. | processx:::throw_error(err, parent = e)[39m
      Execution halted

# chain_error with stop()

    Code
      cat(out$stderr)
    Output
      Error in `do()` at script.R:13:10:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:9:9:
      ! something is wrong here
      Caused by error in `do3()` at script.R:6:9:
      ! because of this
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. global f() at script.R:14:5
       6. global g() at script.R:11:10
       7. global h() at script.R:12:10
       8. global do() at script.R:13:10
       9. processx:::chain_error(do2(), "Failed to base64 encode") at script.R:9:9
      10. | base::withCallingHandlers({
      11. global do2()
      12. processx:::chain_error(do3(), "something is wrong here") at script.R:6:9
      13. | base::withCallingHandlers({
      14. global do3()
      15. base::stop("because of this") at script.R:3:9
      16. | base::.handleSimpleError(function (e)
      17. | local h(simpleError(msg, call))
      18. | processx:::throw_error(err, parent = e)
      19. | base::signalCondition(cond)
      20. | (function (e)
      21. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `do()` at script.R:15:14:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:11:13:
      ! something is wrong here
      Caused by error in `do3()` at script.R:8:13:
      ! because of this
      Type .Last.error to see the more details.

# chain_error with rlang::abort()

    Code
      cat(out$stderr)
    Output
      Error in `do()` at script.R:14:10:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:10:9:
      ! something is wrong here
      Caused by error in `do3()` at script.R:7:9:
      ! because of this
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. global f() at script.R:15:5
       6. global g() at script.R:12:10
       7. global h() at script.R:13:10
       8. global do() at script.R:14:10
       9. processx:::chain_error(do2(), "Failed to base64 encode") at script.R:10:9
      10. | base::withCallingHandlers({ ...
      11. global do2()
      12. processx:::chain_error(do3(), "something is wrong here") at script.R:7:9
      13. | base::withCallingHandlers({ ...
      14. global do3()
      15. rlang::abort("because of this") at script.R:4:9
      16. | rlang:::signal_abort(cnd, .file)
      17. | base::signalCondition(cnd)
      18. | (function (e) ...
      19. | processx:::throw_error(err, parent = e)
      20. | base::signalCondition(cond)
      21. | (function (e) ...
      22. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `do()` at script.R:16:14:
      ! Failed to base64 encode
      Caused by error in `do2()` at script.R:12:13:
      ! something is wrong here
      Caused by error in `do3()` at script.R:9:13:
      ! because of this
      Type .Last.error to see the more details.

# full parent error is printed in non-interactive mode

    Code
      cat(out$stderr)
    Output
      Error in `eval(ei, envir)`:
      ! failed to run external program
      Caused by error in `processx::run(px, c("return", "1"))` at script.R:4:5:
      ! System command 'px' failed
      ---
      Exit status: 1
      Stderr: <empty>
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. processx:::chain_error(processx::run(px, c("return", "1")), "failed to run  at script.R:4:5
       6. | base::withCallingHandlers({
       7. processx::run(px, c("return", "1"))
       8. processx:::throw(new_process_error(res, call = sys.call(), echo = echo,
       9. | base::signalCondition(cond)
      10. | (function (e)
      11. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stdout)
    Output
      Error in `eval(ei, envir)`:
      ! failed to run external program
      Caused by error in `processx::run(px, c("return", "1"))` at script.R:6:9:
      ! System command 'px' failed
      Type .Last.error to see the more details.

---

    Code
      cat(out$stderr)
    Output
      Error in `eval(ei, envir)`:
      ! failed to run external program
      Caused by error in `processx::run(px, c("return", "1"))` at script.R:6:9:
      ! System command 'px' failed
      ---
      Exit status: 1
      Stderr: <empty>
      ---
      Backtrace:
       1. base::source("script.R")
       2. | base::withVisible(eval(ei, envir))
       3. | base::eval(ei, envir)
       4. | base::eval(ei, envir)
       5. processx:::chain_error(processx::run(px, c("return", "1")), "failed to r... at script.R:6:9
       6. | base::withCallingHandlers({ ...
       7. processx::run(px, c("return", "1"))
       8. processx:::throw(new_process_error(res, call = sys.call(), echo = echo, ...
       9. | base::signalCondition(cond)
      10. | (function (e) ...
      11. | processx:::throw_error(err, parent = e)
      Execution halted

---

    Code
      cat(out$stderr)
    Output
      [1m[33mError[39m[22m in `eval(ei, envir)`:
      [33m![39m failed to run external program
      [1mCaused by error[22m in `processx::run(px, c("return", "1"))`[90m at script.R:9:9[39m:
      [33m![39m System command 'px' failed
      ---
      Exit status: 1
      Stderr: <empty>
      ---
      Backtrace:
      [90m 1. [39mbase::[36msource[39m[33m("script.R")[39m
      [90m 2. | base::withVisible(eval(ei, envir))[39m
      [90m 3. | base::eval(ei, envir)[39m
      [90m 4. | base::eval(ei, envir)[39m
      [90m 5. [39mprocessx:::[36mchain_error[39m[33m([39mprocessx::[36mrun[39m[34m([39mpx, [36mc([39m[33m"return"[39m, [33m"1"[39m[36m)[39m[34m)[39m, [33m"failed to r[39m...[90m at script.R:9:9[39m
      [90m 6. | base::withCallingHandlers({ ...[39m
      [90m 7. [39mprocessx::[36mrun[39m[33m([39mpx, [36mc[39m[34m([39m[33m"return"[39m, [33m"1"[39m[34m)[39m[33m)[39m
      [90m 8. [39mprocessx:::throw(new_process_error(res, call = sys.call(), echo = echo, ...
      [90m 9. | base::signalCondition(cond)[39m
      [90m10. | (function (e) ...[39m
      [90m11. | processx:::throw_error(err, parent = e)[39m
      Execution halted

