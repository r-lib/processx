
test_that("fails in windows", {
  skip_other_platforms("windows")
  expect_error(process$new("R", pty = TRUE), "only implemented on Unix",
               class = "error")
})

test_that("pty works", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  p <- process$new("cat", pty = TRUE)
  on.exit(p$kill(), add = TRUE)
  expect_true(p$is_alive())
  if (!p$is_alive()) stop("process not running")

  pr <- p$poll_io(0)
  expect_equal(pr[["output"]], "timeout")

  p$write_input("foobar\n")
  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  if (pr[["output"]] != "ready") stop("no output")
  expect_equal(p$read_output(), "foobar\r\n")
})

test_that("pty echo", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  p <- process$new("cat", pty = TRUE, pty_options = list(echo = TRUE))
  on.exit(p$kill(), add = TRUE)
  expect_true(p$is_alive())
  if (!p$is_alive()) stop("process not running")

  pr <- p$poll_io(0)
  expect_equal(pr[["output"]], "timeout")

  p$write_input("foo")
  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  if (pr[["output"]] != "ready") stop("no output")
  expect_equal(p$read_output(), "foo")

  p$write_input("bar\n")
  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  if (pr[["output"]] != "ready") stop("no output")
  expect_equal(p$read_output(), "bar\r\nfoobar\r\n")
})

test_that("read_output_lines() fails for pty", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  p <- process$new("cat", pty = TRUE)
  p$write_input("foobar\n")
  expect_error(p$read_output_lines(), "Cannot read lines from a pty")

  pr <- p$poll_io(300)
  expect_equal(pr[["output"]], "ready")
  if (pr[["output"]] != "ready") stop("no output")
  expect_equal(p$read_output(), "foobar\r\n")
})
