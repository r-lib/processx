
context("connections")

test_that("process_connection creates good objects", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  cat("foo\n", "bar\n", sep = "", file = tmp)

  con <- process_connection(file(tmp, open = "r", blocking = TRUE))
  expect_identical(readLines(con, n = 1), "foo")
  expect_identical(readLines(con), "bar")

  expect_error(close(con), NA)
})

test_that("can be closed multiple times", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  cat("foo\n", "bar\n", sep = "", file = tmp)

  con <- process_connection(file(tmp, open = "r", blocking = TRUE))

  expect_error(close(con), NA)
  expect_error(close(con), NA)
  expect_error(close(con), NA)
})

test_that("process_connection has reference semantics", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  cat("foo\n", "bar\n", sep = "", file = tmp)

  con <- process_connection(file(tmp, open = "r", blocking = TRUE))

  con2 <- con

  close(con)

  expect_true(is_closed(con2))
})

test_that("print / summary does not fail", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  cat("foo\n", "bar\n", sep = "", file = tmp)

  con <- process_connection(file(tmp, open = "r", blocking = TRUE))
  close(con)

  expect_error(capture.output(print(con)), NA)
  expect_error(capture.output(summary(con)), NA)
})
