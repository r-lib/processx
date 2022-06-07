
test_that("simple error", {

  out <- run_script({
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stderr))

  out <- run_script({
    options(rlib_interactive = TRUE)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stdout))
})
