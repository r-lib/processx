library(testthat)
library(processx)

Sys.setenv("R_TESTS" = "")
test_check("processx", reporter = "summary")
