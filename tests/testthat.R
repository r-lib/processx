library(testthat)
library(processx)

if (Sys.getenv("NOT_CRAN") != "" || .Platform$OS.type != "windows") {
  test_check("processx")
}
