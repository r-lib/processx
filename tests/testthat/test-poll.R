
context("poll")

test_that("polling for output available", {
  p <- process$new(commandline = "sleep 1; ls", stdout = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "timeout", error = "closed"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "closed"))

  p$read_output_lines()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "closed"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "closed"))

  close(p$get_output_connection())
  expect_equal(p$poll_io(-1), c(output = "closed", error = "closed"))
})

test_that("polling for stderr", {
  p <- process$new(commandline = "sleep 1; ls 1>&2", stderr = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "closed", error = "timeout"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "closed", error = "pollin"))

  p$read_error_lines()
  expect_equal(p$poll_io(-1), c(output = "closed", error = "pollin"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "closed", error = "pollin"))

  close(p$get_error_connection())
  expect_equal(p$poll_io(-1), c(output = "closed", error = "closed"))
})

test_that("polling for both stdout and stderr", {
  p <- process$new(commandline = "sleep 1; ls 1>&2; ls",
                   stdout = "|", stderr = "|")

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "timeout", error = "timeout"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "pollin"))

  p$read_error_lines()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "pollin"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "pollin", error = "pollin"))

  close(p$get_output_connection())
  close(p$get_error_connection())
  expect_equal(p$poll_io(-1), c(output = "closed", error = "closed"))
})
