
context("process")

test_that("process works", {

  skip_on_cran()
  skip_other_platforms("unix")
  skip_without_command("ls")

  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp), add = TRUE)

  p <- process$new("sleep", "5")
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  expect_true(p$is_alive())
})
