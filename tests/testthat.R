library(testthat)
library(processx)

Sys.setenv("R_TESTS" = "")
if (Sys.getenv("NOT_CRAN") != "" || .Platform$OS.type != "windows") {
  test_check("processx", reporter = "summary", filter = "poll2")
}

## Wait until the child processes have surely finished,
## on windows. This might fix some win-builder troubles.

if (.Platform$OS.type == "windows") Sys.sleep(5)
