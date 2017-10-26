
context("stress test")

test_that("can start 100 processes quickly", {
  skip_if_no_command("ls")
  expect_silent(for (i in 1:100) run("ls"))
})
