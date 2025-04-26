# simple error with cli and colors

    Code
      cat(out$stderr)
    Output
      [1m[33mError[39m[22m in `f()`[90m at script.R:5:5[39m:
      [33m![39m This failed
      ---
      Backtrace:
      [90m1. [39mbase::[1msource[22m[38;5;178m([38;5;37m"script.R"[38;5;178m)[39m
      [90m2. | base::withVisible(eval(ei, envir))[39m
      [90m3. | base::eval(ei, envir)[39m
      [90m4. | base::eval(ei, envir)[39m
      [90m5. [39mglobal [1mf[22m[38;5;178m()[39m[90m at script.R:5:5[39m
      [90m6. [39mprocessx:::[1mthrow[22m[38;5;178m([38;5;37m"This failed"[38;5;178m)[39m[90m at script.R:4:10[39m
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
      [1m[33mError[39m[22m in `do()`[90m at script.R:19:14[39m:
      [33m![39m Failed to base64 encode
      [1mCaused by error[22m in `do2()`[90m at script.R:15:13[39m:
      [33m![39m something is wrong here
      [1mCaused by error[22m in `do3()`[90m at script.R:12:13[39m:
      [33m![39m because of this
      ---
      Backtrace:
      [90m 1. [39mbase::[1msource[22m[38;5;178m([38;5;37m"script.R"[38;5;178m)[39m
      [90m 2. | base::withVisible(eval(ei, envir))[39m
      [90m 3. | base::eval(ei, envir)[39m
      [90m 4. | base::eval(ei, envir)[39m
      [90m 5. [39mglobal [1mf[22m[38;5;178m()[39m[90m at script.R:20:9[39m
      [90m 6. [39mglobal [1mg[22m[38;5;178m()[39m[90m at script.R:17:14[39m
      [90m 7. [39mglobal [1mh[22m[38;5;178m()[39m[90m at script.R:18:14[39m
      [90m 8. [39mglobal [1mdo[22m[38;5;178m()[39m[90m at script.R:19:14[39m
      [90m 9. [39mprocessx:::[1mchain_error[22m[38;5;178m([39m[1mdo2[22m[33m()[39m, [38;5;37m"Failed to base64 encode"[38;5;178m)[39m[90m at script.R:15:13[39m
      [90m10. | base::withCallingHandlers({ ...[39m
      [90m11. [39mglobal [1mdo2[22m[38;5;178m()[39m
      [90m12. [39mprocessx:::[1mchain_error[22m[38;5;178m([39m[1mdo3[22m[33m()[39m, [38;5;37m"something is wrong here"[38;5;178m)[39m[90m at script.R:12:13[39m
      [90m13. | base::withCallingHandlers({ ...[39m
      [90m14. [39mglobal [1mdo3[22m[38;5;178m()[39m
      [90m15. [39mprocessx:::[1mthrow[22m[38;5;178m([38;5;37m"because of this"[38;5;178m)[39m[90m at script.R:9:13[39m
      [90m16. | base::signalCondition(cond)[39m
      [90m17. | (function (e) ...[39m
      [90m18. | processx:::throw_error(err, parent = e)[39m
      [90m19. | base::signalCondition(cond)[39m
      [90m20. | (function (e) ...[39m
      [90m21. | processx:::throw_error(err, parent = e)[39m
      Execution halted

# full parent error is printed in non-interactive mode

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
      [90m 1. [39mbase::[1msource[22m[38;5;178m([38;5;37m"script.R"[38;5;178m)[39m
      [90m 2. | base::withVisible(eval(ei, envir))[39m
      [90m 3. | base::eval(ei, envir)[39m
      [90m 4. | base::eval(ei, envir)[39m
      [90m 5. [39mprocessx:::[1mchain_error[22m[38;5;178m([39mprocessx::[1mrun[22m[33m([39mpx, [1mc[22m[34m([39m[38;5;37m"return"[39m, [38;5;37m"1"[39m[34m)[39m[33m)[39m, [38;5;37m"failed to r[39m...[90m at script.R:9:9[39m
      [90m 6. | base::withCallingHandlers({ ...[39m
      [90m 7. [39mprocessx::[1mrun[22m[38;5;178m([39mpx, [1mc[22m[33m([39m[38;5;37m"return"[39m, [38;5;37m"1"[39m[33m)[39m[38;5;178m)[39m
      [90m 8. [39mprocessx:::throw(new_process_error(res, call = sys.call(), echo = echo, ...
      [90m 9. | base::signalCondition(cond)[39m
      [90m10. | (function (e) ...[39m
      [90m11. | processx:::throw_error(err, parent = e)[39m
      Execution halted

