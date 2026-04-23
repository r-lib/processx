test_that("Output and error are discarded by default", {
  skip_if_no_srcrefs()
  px <- get_tool("px")
  p <- process$new(px, c("outln", "foobar"))
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  expect_snapshot(error = TRUE, {
    p$read_output_lines(n = 1)
    p$read_all_output_lines()
    p$read_all_output()
    p$read_error_lines(n = 1)
    p$read_all_error_lines()
    p$read_all_error()
  })
})

test_that("We can get the output", {
  px <- get_tool("px")

  p <- process$new(
    px,
    c("out", "foo\nbar\nfoobar\n"),
    stdout = "|",
    stderr = "|"
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  out <- p$read_all_output_lines()
  expect_identical(out, c("foo", "bar", "foobar"))
})

test_that("We can get the error stream", {
  tmp <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp), add = TRUE)

  cat(">&2 echo hello", ">&2 echo world", sep = "\n", file = tmp)
  Sys.chmod(tmp, "700")

  p <- process$new(tmp, stderr = "|")
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  out <- sort(p$read_all_error_lines())
  expect_identical(out, c("hello", "world"))
})

test_that("Output & error at the same time", {
  tmp <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp), add = TRUE)

  cat(
    if (os_type() == "windows") "@echo off",
    ">&2 echo hello",
    "echo wow",
    ">&2 echo world",
    "echo wooow",
    sep = "\n",
    file = tmp
  )
  Sys.chmod(tmp, "700")

  p <- process$new(tmp, stdout = "|", stderr = "|")
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  out <- p$read_all_output_lines()
  expect_identical(out, c("wow", "wooow"))

  err <- p$read_all_error_lines()
  expect_identical(err, c("hello", "world"))
})

test_that("Output and error to specific files", {
  tmp <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp), add = TRUE)

  cat(
    if (os_type() == "windows") "@echo off",
    ">&2 echo hello",
    "echo wow",
    ">&2 echo world",
    "echo wooow",
    sep = "\n",
    file = tmp
  )
  Sys.chmod(tmp, "700")

  tmpout <- tempfile()
  tmperr <- tempfile()

  p <- process$new(tmp, stdout = tmpout, stderr = tmperr)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()

  ## In theory this is a race condition, because the OS might be still
  ## writing the files. But it is hard to wait until they are done.
  ## We'll see if this fails in practice, hopefully not.
  expect_identical(readLines(tmpout), c("wow", "wooow"))
  expect_identical(readLines(tmperr), c("hello", "world"))
})

test_that("Output and error can be appended to files with >>", {
  px <- get_tool("px")
  tmpout <- tempfile()
  tmperr <- tempfile()
  on.exit(unlink(c(tmpout, tmperr)), add = TRUE)

  ## Write initial content into the files
  writeLines("existing-out", tmpout)
  writeLines("existing-err", tmperr)

  p <- process$new(
    px,
    c("outln", "appended-out", "errln", "appended-err"),
    stdout = paste0(">>", tmpout),
    stderr = paste0(">>", tmperr)
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  p$wait()

  expect_identical(readLines(tmpout), c("existing-out", "appended-out"))
  expect_identical(readLines(tmperr), c("existing-err", "appended-err"))

  ## Also verify that get_output_file / get_error_file return the plain path
  ## (use normalizePath on both sides to handle platform symlinks like
  ## /var -> /private/var on macOS)
  expect_identical(
    normalizePath(p$get_output_file()),
    normalizePath(tmpout)
  )
  expect_identical(
    normalizePath(p$get_error_file()),
    normalizePath(tmperr)
  )
})

test_that(">> creates the file if it does not exist", {
  px <- get_tool("px")
  tmpout <- tempfile()
  tmperr <- tempfile()
  on.exit(unlink(c(tmpout, tmperr)), add = TRUE)

  ## Files must not exist before the process runs
  expect_false(file.exists(tmpout))
  expect_false(file.exists(tmperr))

  p <- process$new(
    px,
    c("outln", "new-out", "errln", "new-err"),
    stdout = paste0(">>", tmpout),
    stderr = paste0(">>", tmperr)
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  p$wait()

  expect_identical(readLines(tmpout), "new-out")
  expect_identical(readLines(tmperr), "new-err")
})

test_that("is_incomplete", {
  px <- get_tool("px")
  p <- process$new(px, c("out", "foo\nbar\nfoobar\n"), stdout = "|")
  on.exit(p$kill(), add = TRUE)

  expect_true(p$is_incomplete_output())

  p$read_output_lines(n = 1)
  expect_true(p$is_incomplete_output())

  p$read_all_output_lines()
  expect_false(p$is_incomplete_output())
})

test_that("readChar on IO, unix", {
  ## Need to skip, because of the different EOL character
  skip_other_platforms("unix")

  px <- get_tool("px")

  p <- process$new(px, c("outln", "hello world!"), stdout = "|")
  on.exit(p$kill(), add = TRUE)
  p$wait()

  p$poll_io(-1)
  expect_equal(p$read_output(5), "hello")
  expect_equal(p$read_output(5), " worl")
  expect_equal(p$read_output(5), "d!\n")
})

test_that("readChar on IO, windows", {
  ## Need to skip, because of the different EOL character
  skip_other_platforms("windows")

  px <- get_tool("px")
  p <- process$new(px, c("outln", "hello world!"), stdout = "|")
  on.exit(p$kill(), add = TRUE)
  p$wait()

  p$poll_io(-1)
  expect_equal(p$read_output(5), "hello")
  p$poll_io(-1)
  expect_equal(p$read_output(5), " worl")
  p$poll_io(-1)
  expect_equal(p$read_output(5), "d!\r\n")
})

test_that("same pipe", {
  skip_if_no_srcrefs()
  px <- get_tool("px")
  cmd <- c("out", "o1", "err", "e1", "out", "o2", "err", "e2")
  p <- process$new(px, cmd, stdout = "|", stderr = "2>&1")
  on.exit(p$kill(), add = TRUE)
  p$wait(2000)
  expect_equal(p$get_exit_status(), 0L)

  out <- p$read_all_output()
  expect_equal(out, "o1e1o2e2")
  expect_snapshot(error = TRUE, p$read_all_error_lines())
})

test_that("same file", {
  skip_if_no_srcrefs()
  px <- get_tool("px")
  cmd <- c("out", "o1", "err", "e1", "out", "o2", "errln", "e2")
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  p <- process$new(px, cmd, stdout = tmp, stderr = "2>&1")
  p$wait(2000)
  p$kill()
  expect_equal(p$get_exit_status(), 0L)

  expect_equal(readLines(tmp), "o1e1o2e2")
  expect_snapshot(error = TRUE, p$read_all_output_lines())
  expect_snapshot(error = TRUE, p$read_all_error_lines())
})

test_that("same NULL, for completeness", {
  skip_if_no_srcrefs()
  px <- get_tool("px")
  cmd <- c("out", "o1", "err", "e1", "out", "o2", "errln", "e2")
  p <- process$new(px, cmd, stdout = NULL, stderr = "2>&1")
  p$wait(2000)
  p$kill()
  expect_equal(p$get_exit_status(), 0L)
  expect_snapshot(error = TRUE, p$read_all_output_lines())
  expect_snapshot(error = TRUE, p$read_all_error_lines())
})
