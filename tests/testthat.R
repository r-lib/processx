library(testthat)
library(processx)

## Do not run tests on CRAN Windows

if (Sys.getenv("NOT_CRAN", "") != "" || .Platform$OS.type != "windows") {
  test_check("processx")
}
