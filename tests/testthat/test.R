
context("process")

test_that("process works", {

  skip_on_cran()

  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp), add = TRUE)

  win  <- c("ping", "-n", "6", "127.0.0.1")
  unix <- c("sleep", "5")
  cmd <- if (os_type() == "windows") win else unix

  p <- process$new(cmd[1], cmd[-1])
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  expect_true(p$is_alive())
})
