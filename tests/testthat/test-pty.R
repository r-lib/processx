
context("pty")

test_that("pty works", {
  skip_other_platforms("unix")

  p <- process$new("cat", pty = TRUE)
  on.exit(p$kill(), add = TRUE)
  expect_true(p$is_alive())

  pr <- p$poll_io(0)
  expect_equal(pr[["output"]], "timeout")

  p$write_input("foo")
  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  expect_equal(p$read_output(), "foo")

  p$write_input("bar\n")
  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  expect_equal(p$read_output(), "bar\r\nfoobar\r\n")
})
