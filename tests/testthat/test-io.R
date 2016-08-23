
context("io")

test_that("We can get the output", {

  skip_on_cran()

  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp), add = TRUE)
  cat("foo", file = file.path(tmp, "foo"))
  cat("bar", file = file.path(tmp, "bar"))

  win  <- paste("dir /b", shQuote(tmp))
  unix <- paste("ls", shQuote(tmp))

  p <- process$new(
    commandline = if (os_type() == "windows") win else unix
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()
  out <- sort(p$read_output_lines())
  expect_identical(out, c("bar", "foo"))
})

test_that("We can get the error stream", {

  skip_on_cran()

  tmp <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp), add = TRUE)

  cat(">&2 echo hello", ">&2 echo world", sep = "\n", file = tmp)
  Sys.chmod(tmp, "700")

  p <- process$new(tmp, stderr = TRUE)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()
  out <- sort(p$read_error_lines())
  expect_identical(out, c("hello", "world"))
})

test_that("Output & error at the same time", {

  skip_on_cran()

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

  p <- process$new(tmp)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()
  out <- p$read_output_lines()
  expect_identical(out, c("wow", "wooow"))

  err <- p$read_error_lines()
  expect_identical(err, c("hello", "world"))
})

test_that("Output and error to specific files", {

  skip_on_cran()

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

  out <- p$read_output_lines()
  expect_identical(out, c("wow", "wooow"))

  err <- p$read_error_lines()
  expect_identical(err, c("hello", "world"))

  expect_identical(readLines(tmpout), c("wow", "wooow"))
  expect_identical(readLines(tmperr), c("hello", "world"))
})
