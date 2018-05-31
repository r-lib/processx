
context("poll")

test_that("polling for output available", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "1", "outln", "foobar"), stdout = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "timeout", error = "nopipe",
                               process = "nopipe"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "ready", error = "nopipe",
                                process = "nopipe"))

  p$read_output_lines()
  expect_equal(p$poll_io(-1), c(output = "ready", error = "nopipe",
                                process = "nopipe"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "ready", error = "nopipe",
                                process = "nopipe"))

  close(p$get_output_connection())
  expect_equal(p$poll_io(-1), c(output = "closed", error = "nopipe",
                                process = "nopipe"))
})

test_that("polling for stderr", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "1", "errln", "foobar"), stderr = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "nopipe", error = "timeout",
                               process = "nopipe"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "ready",
                                process = "nopipe"))

  p$read_error_lines()
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "ready",
                                process = "nopipe"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "ready",
                                process = "nopipe"))

  close(p$get_error_connection())
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "closed",
                                process = "nopipe"))
})

test_that("polling for both stdout and stderr", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "1", "errln", "foo", "outln", "bar"),
                   stdout = "|", stderr = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "timeout", error = "timeout",
                               process = "nopipe"))

  p$wait()
  expect_true("ready" %in% p$poll_io(-1))

  p$read_error_lines()
  expect_true("ready" %in% p$poll_io(-1))

  p$kill()
  expect_true("ready" %in% p$poll_io(-1))

  close(p$get_output_connection())
  close(p$get_error_connection())
  expect_equal(p$poll_io(-1), c(output = "closed", error = "closed",
                                process = "nopipe"))
})

test_that("multiple polls", {

  px <- get_tool("px")
  p <- process$new(
    px, c("sleep", "1", "outln", "foo", "sleep", "1", "outln", "bar"),
    stdout = "|", stderr = "|")

  out <- character()
  while (p$is_alive()) {
    p$poll_io(2000)
    out <- c(out, p$read_output_lines())
  }

  expect_identical(out, c("foo", "bar"))
})
