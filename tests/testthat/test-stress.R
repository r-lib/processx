test_that("can start 100 processes quickly", {
  skip_on_cran()
  px <- get_tool("px")
  expect_error(for (i in 1:100) run(px), NA)
  gc()
})

test_that("run() a lot of times, with small timeouts", {
  skip_on_cran()
  px <- get_tool("px")
  for (i in 1:100) {
    tic <- Sys.time()
    err <- tryCatch(
      run(px, c("sleep", "5"), timeout = 1 / 1000),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < as.difftime(3, units = "secs"))
  }
  gc()
})

test_that("run() and kill while polling", {
  skip_on_cran()
  px <- get_tool("px")
  for (i in 1:10) {
    tic <- Sys.time()
    err <- tryCatch(
      run(px, c("sleep", "5"), timeout = 1 / 2),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < as.difftime(3, units = "secs"))
  }
  gc()
})
