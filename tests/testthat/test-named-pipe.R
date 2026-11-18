test_that("named_pipe_tempfile()", {
  skip_on_os("windows")
  name <- named_pipe_tempfile("foo")
  expect_true(is_string(name))
  expect_match(basename(name), "^foo")
})

test_that("unix named pipes", {
  skip_on_os("windows")
  name <- named_pipe_tempfile()
  on.exit(unlink(name), add = TRUE)
  pipe <- create_named_pipe(name)
  expect_s3_class(pipe, "unix_named_pipe")
  expect_true(is_pipe_open(pipe))

  # w+ mode, so we can read back what we wrote
  write_lines_named_pipe(pipe, c("foo", "bar"))
  expect_equal(readLines(pipe$handle, n = 2), c("foo", "bar"))

  close_named_pipe(pipe)
  expect_false(is_pipe_open(pipe))
})

test_that("is_pipe_open() errors for a non-fifo handle", {
  skip_on_os("windows")
  pipe <- structure(list(handle = 1L), class = c("unix_named_pipe", "named_pipe"))
  expect_snapshot(error = TRUE, is_pipe_open(pipe))
})

test_that("windows named pipe functions error on unix", {
  skip_on_os("windows")
  pipe <- structure(
    list(handle = NULL),
    class = c("windows_named_pipe", "named_pipe")
  )
  expect_error(is_pipe_open(pipe), "only valid on Windows")
  expect_error(close_named_pipe(pipe), "only valid on Windows")
  expect_error(write_lines_named_pipe(pipe, "foo"), "only valid on Windows")
  expect_error(write_lines_named_pipe(pipe, "foo\n"), "only valid on Windows")
})
