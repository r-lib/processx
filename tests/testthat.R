library(testthat)
library(processx)

Sys.setenv("R_TESTS" = "")
test_check("processx", reporter = "summary", filter = "poll2")
test_check("processx", reporter = "summary", filter = "stress")
