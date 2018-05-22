
context("process")

test_that("process works", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "5"))
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  expect_true(p$is_alive())
})

test_that("get_exit_status", {

  px <- get_tool("px")
  p <- process$new(px, c("return", "1"))
  p$wait()
  expect_identical(p$get_exit_status(), 1L)
})

test_that("non existing process", {
  expect_error(process$new(tempfile()))
})

test_that("post processing", {

  px <- get_tool("px")
  p <- process$new(
    px, c("return", "0"), post_process = function() "foobar")
  p$wait(5000)
  p$kill()
  expect_equal(p$get_result(), "foobar")

  p <- process$new(
    px, c("sleep", "5"), post_process = function() "yep")
  expect_error(p$get_result(), "alive")
  p$kill()
  expect_equal(p$get_result(), "yep")

  ## Only runs once
  xx <- 0
  p <- process$new(
    px, c("return", "0"), post_process = function() xx <<- xx + 1)
  p$wait(5000)
  p$kill()
  p$get_result()
  expect_equal(xx, 1)
  p$get_result()
  expect_equal(xx, 1)
})

test_that("working directory", {
  px  <- get_tool("px")
  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  cat("foo\nbar\n", file = file.path(tmp, "file"))

  p <- process$new(px, c("cat", "file"), wd = tmp, stdout = "|")
  p$wait()
  expect_equal(p$read_all_output_lines(), c("foo", "bar"))
})

test_that("working directory does not exist", {
  px <- get_tool("px")
  expect_error(process$new(px, wd = tempfile()))
})
