
context("stress test")

test_that("can start 100 processes quickly", {
  skip_on_cran()
  sl <- sleep(0, commandline = FALSE)
  expect_silent(for (i in 1:100) run(sl[1], sl[-1]))
})

test_that("run() a lot of times, with small timeouts", {
  skip_on_cran()
  sl <- sleep(5, commandline = FALSE)
  for (i in 1:100) {
    tic <- Sys.time()
    err <- tryCatch(
      run(sl[1], sl[-1], timeout = 0.000001),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < 3)
  }
})

test_that("run() a lot of times, with small timeouts", {
  skip_on_cran()
  sl <- sleep(5, commandline = TRUE)
  for (i in 1:100) {
    tic <- Sys.time()
    err <- tryCatch(
      run(commandline = sl, timeout = 0.000001),
      error = identity
    )
    expect_s3_class(err, "system_command_timeout_error")
    expect_true(Sys.time() - tic < 3)
  }
})
