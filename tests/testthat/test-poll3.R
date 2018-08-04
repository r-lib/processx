
context("poll connection")

test_that("poll connection", {
  px <- get_tool("px")
  p <- process$new(px, c("sleep", ".5", "outln", "foobar"))
  on.exit(p$kill())

  ## Timeout
  expect_equal(p$poll_io(0), c(output = "nopipe", error = "nopipe",
                               process = "timeout"))

  p$wait()
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "nopipe",
                                process = "ready"))

  p$kill()
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "nopipe",
                                process = "closed"))

  close(p$get_poll_connection())
  expect_equal(p$poll_io(-1), c(output = "nopipe", error = "nopipe",
                                process = "closed"))
})

test_that("poll connection + stdout", {

  px <- get_tool("px")
  p1 <- process$new(px, c("outln", "foobar"), stdout = "|")
  on.exit(p1$kill(), add = TRUE)

  expect_false(p1$has_poll_connection())

  p2 <- process$new(px, c("sleep", "0.5", "outln", "foobar"), stdout = "|",
                   poll_connection = TRUE)
  on.exit(p2$kill(), add = TRUE)

  expect_equal(p2$poll_io(0), c(output = "timeout", error = "nopipe",
                                process = "timeout"))

  pr <- p2$poll_io(-1)
  expect_true("ready" %in% pr)
})

test_that("poll connection + stderr", {

  px <- get_tool("px")
  p1 <- process$new(px, c("errln", "foobar"), stderr = "|")
  on.exit(p1$kill(), add = TRUE)

  expect_false(p1$has_poll_connection())

  p2 <- process$new(px, c("sleep", "0.5", "errln", "foobar"), stderr = "|",
                   poll_connection = TRUE)
  on.exit(p2$kill(), add = TRUE)

  expect_equal(p2$poll_io(0), c(output = "nopipe", error = "timeout",
                                process = "timeout"))

})
