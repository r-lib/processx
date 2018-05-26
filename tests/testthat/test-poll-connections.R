
context("polling connections")

test_that("poll a connection", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", ".5", "outln", "foobar"), stdout = "|")
  on.exit(p$kill())
  out <- p$get_output_connection()

  ## Timeout
  expect_equal(poll(list(out), 0)[[1]], "timeout")

  expect_equal(poll(list(out), 2000)[[1]], "ready")

  p$read_output_lines()
  expect_equal(poll(list(out), 2000)[[1]], "ready")

  close(out)
  expect_equal(poll(list(out), 0)[[1]], "closed")
})

test_that("poll a connection and a process", {

  px <- get_tool("px")
  p1 <- process$new(px, c("sleep", ".5", "outln", "foobar"), stdout = "|")
  p2 <- process$new(px, c("sleep", ".5", "outln", "foobar"), stdout = "|")
  on.exit(p1$kill(), add = TRUE)
  on.exit(p2$kill(), add = TRUE)
  out <- p1$get_output_connection()

  ## Timeout
  expect_equal(
    poll(list(out, p2), 0),
    list(
      "timeout",
      c(output = "timeout", error = "nopipe", process = "nopipe"))
  )

  ## At least one of them is ready. Usually both on Unix, but on Windows
  ## it is different because the IOCP is a queue
  pr <- poll(list(out, p2), 2000)
  expect_true(pr[[1]] == "ready"  || pr[[2]][["output"]] == "ready")

  p1$poll_io(2000)
  p2$poll_io(2000)
  p1$read_output_lines()
  p2$read_output_lines()
  pr <- poll(list(out, p2), 2000)
  expect_true(pr[[1]] == "ready"  || pr[[2]][["output"]] == "ready")

  p1$kill()
  p2$kill()
  pr <- poll(list(out, p2), 2000)
  expect_true(pr[[1]] == "ready"  || pr[[2]][["output"]] == "ready")

  close(out)
  close(p2$get_output_connection())
  expect_equal(
    poll(list(out, p2), 2000),
    list("closed", c(output = "closed", error = "nopipe", process = "nopipe"))
  )
})
