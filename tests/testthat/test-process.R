
context("process")

test_that("process works", {

  win  <- sleep(5, commandline = FALSE)
  unix <- c("sleep", "5")
  cmd <- if (os_type() == "windows") win else unix

  p <- process$new(cmd[1], cmd[-1])
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  Sys.sleep(.1)
  expect_true(p$is_alive())
})

test_that("get_exit_status", {
  cmd <- if (os_type() == "windows") {
    "cmd /c exit 1"
  } else {
    "echo alive && exit 1"
  }
  p <- process$new(commandline = cmd)
  p$wait()
  expect_identical(p$get_exit_status(), 1L)
})

test_that("restart", {

  cmd <- sleep(5, commandline = FALSE)
  p <- process$new(cmd[1], cmd[-1])
  expect_true(p$is_alive())

  p$kill(grace = 0)

  expect_false(p$is_alive())

  p$restart()
  expect_true(p$is_alive())

  p$kill(grace = 0)
})
