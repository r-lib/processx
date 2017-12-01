
context("stress test")

test_that("can start 100 processes quickly", {
  skip_on_cran()
  sl <- sleep(0)
  expect_error(for (i in 1:100) run(sl[1], sl[-1]), NA)
})

test_that("run() a lot of times, with small timeouts", {
  skip_on_cran()
  sl <- sleep(5)
  for (i in 1:100) {
    tic <- Sys.time()
    err <- tryCatch(
      run(sl[1], sl[-1], timeout = 0.000001),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < as.difftime(3, units = "secs"))
  }
})

test_that("run() a lot of times, with small timeouts", {
  skip_on_cran()
  sl <- sleep(5)
  for (i in 1:100) {
    tic <- Sys.time()
    err <- tryCatch(
      run(commandline = paste(sl, collapse = " "), timeout = 0.000001),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < as.difftime(3, units = "secs"))
  }
})
