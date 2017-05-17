
context("io")

test_that("We can get the output", {

  win  <- "dir /b /A"
  unix <- "ls -A"

  p <- process$new(
    commandline = if (os_type() == "windows") win else unix,
    stdout = "|", stderr = "|"
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  out <- sort(p$read_all_output_lines())
  expect_identical(sort(out), sort(dir(no..=TRUE, all.files=TRUE)))
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
    sep = "\n", file = tmp
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
    sep = "\n", file = tmp
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

test_that("isIncomplete", {

  cmd <- if (os_type() == "windows") "dir /b /A" else "ls -A"

  p <- process$new(commandline = cmd, stdout = "|")
  con <- p$get_output_connection()

  expect_true(isIncomplete(con))

  p$read_output_lines(n = 1)
  expect_true(isIncomplete(con))

  p$read_all_output_lines()
  expect_false(isIncomplete(con))

  close(con)
})

test_that("can read after process was finalized, unix", {

  skip_other_platforms("unix")

  p <- process$new("ls", stdout = "|")
  con <- p$get_output_connection()
  rm(p) ; gc()

  expect_equal(sort(readLines(con)), sort(dir()))
})

test_that("can read after process was finalized, windows", {

  skip_other_platforms("windows")

  p <- process$new(commandline = "dir /b /A", stdout = "|")
  con <- p$get_output_connection()
  p$wait()
  rm(p) ; gc()

  out <- character()
  while (isIncomplete(con)) out <- c(out, readLines(con))

  expect_equal(sort(out), sort(dir()))
})

test_that("readChar on IO, unix", {

  skip_other_platforms("unix")

  p <- process$new("echo", "hello world!", stdout = "|")
  con <- p$get_output_connection()
  p$wait()

  p$poll_io(-1)
  expect_equal(readChar(con, 5), "hello")
  expect_equal(readChar(con, 5), " worl")
  expect_equal(readChar(con, 5), "d!\n")
})

test_that("readChar on IO, windows", {

  skip_other_platforms("windows")

  p <- process$new(commandline = "echo hello world!", stdout = "|")
  con <- p$get_output_connection()
  p$wait()

  p$poll_io(-1)
  expect_equal(readChar(con, 5), "hello")
  p$poll_io(-1)
  expect_equal(readChar(con, 5), " worl")
  p$poll_io(-1)
  expect_equal(readChar(con, 5), "d!\r\n")
})
