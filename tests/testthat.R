library(testthat)
library(processx)

Sys.setenv("R_TESTS" = "")

if (ps::ps_is_supported()) {
  reporter <- ps::CleanupReporter(testthat::SummaryReporter)$new()
} else {
  ## ps does not support this platform
  reporter <- "summary"
}

test_check("ps", reporter = reporter)
