
context("io")

test_that("We can get the output", {

  cmd     <- if (os_type() == "windows") "dir /b /A" else "ls -A"
  newline <- if (os_type() == "windows") "\r\n" else "\n"
  all_files <- sort(dir(no..=TRUE, all.files=TRUE))

  p1 <- process$new(commandline = cmd, stdout = "|", stderr = "|")$wait()
  on.exit(try_silently(p1$kill(grace = 0)), add = TRUE)
  out <- sort(p1$read_all_output_lines())
  expect_identical(out, all_files)

  # read_output_lines and read_all_output_lines don't repeat content
  p2 <- process$new(commandline = cmd, stdout = "|", stderr = "|")$wait()
  on.exit(try_silently(p2$kill(grace = 0)), add = TRUE)
  expect_identical(sort(p2$read_output_lines(n = 1)), all_files[1])
  expect_identical(sort(p2$read_all_output_lines()), all_files[-1])
  expect_identical(sort(p2$read_all_output_lines()), character(0))

  # read_all_output returns a string
  p3 <- process$new(commandline = cmd, stdout = "|", stderr = "|")$wait()
  on.exit(try_silently(p3$kill(grace = 0)), add = TRUE)
  out <- strsplit(p3$read_all_output(), newline)[[1]]
  out <- sort(out)
  expect_identical(out, all_files)
  # Subsequent calls return "". (Should it be character(0)?)
  expect_identical(p3$read_all_output(), "")


  # ==== Same tests as above, but with file output instead of pipes ====
  p4 <- process$new(commandline = cmd)$wait()
  on.exit(try_silently(p4$kill(grace = 0)), add = TRUE)
  out <- sort(p4$read_all_output_lines())
  expect_identical(out, all_files)

  # read_output_lines and read_all_output_lines don't repeat content
  p5 <- process$new(commandline = cmd)$wait()
  on.exit(try_silently(p5$kill(grace = 0)), add = TRUE)
  expect_identical(sort(p5$read_output_lines(n = 1)), all_files[1])
  expect_identical(sort(p5$read_all_output_lines()), all_files[-1])
  expect_identical(sort(p5$read_all_output_lines()), character(0))

  # read_all_output returns a string
  p6 <- process$new(commandline = cmd)$wait()
  on.exit(try_silently(p6$kill(grace = 0)), add = TRUE)
  out <- strsplit(p6$read_all_output(), newline)[[1]]
  out <- sort(out)
  expect_identical(out, all_files)
  # Subsequent calls return "". (Should it be character(0)?)
  expect_identical(p6$read_all_output(), "")
})

test_that("We can get the error stream", {

  newline <- if (os_type() == "windows") "\r\n" else "\n"

  tmp <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp), add = TRUE)

  cat(">&2 echo hello", ">&2 echo world", sep = "\n", file = tmp)
  Sys.chmod(tmp, "700")

  p1 <- process$new(tmp, stderr = "|")$wait()
  on.exit(try_silently(p1$kill(grace = 0)), add = TRUE)
  expect_identical(p1$read_all_error_lines(), c("hello", "world"))

  # read_error_lines and read_all_error_lines don't repeat content
  p2 <- process$new(tmp, stderr = "|")$wait()
  on.exit(try_silently(p2$kill(grace = 0)), add = TRUE)
  expect_identical(p2$read_error_lines(n = 1), "hello")
  expect_identical(p2$read_all_error_lines(), "world")
  expect_identical(p2$read_all_error_lines(), character(0))

  # read_all_error returns a string
  p3 <- process$new(tmp, stderr = "|")$wait()
  on.exit(try_silently(p3$kill(grace = 0)), add = TRUE)
  expect_identical(p3$read_all_error(), paste0("hello", newline, "world", newline))
  # Subsequent calls return ""
  expect_identical(p3$read_all_error(), "")


  # ==== Same tests as above, but with file output instead of pipes ====
  p4 <- process$new(tmp)$wait()
  on.exit(try_silently(p4$kill(grace = 0)), add = TRUE)
  expect_identical(p4$read_all_error_lines(), c("hello", "world"))

  # read_error_lines and read_all_error_lines don't repeat content
  p5 <- process$new(tmp)$wait()
  on.exit(try_silently(p5$kill(grace = 0)), add = TRUE)
  expect_identical(p5$read_error_lines(n = 1), "hello")
  expect_identical(p5$read_all_error_lines(), "world")
  expect_identical(p5$read_all_error_lines(), character(0))

  # read_all_error returns a string
  p6 <- process$new(tmp)$wait()
  on.exit(try_silently(p6$kill(grace = 0)), add = TRUE)
  expect_identical(p6$read_all_error(), paste0("hello", newline, "world", newline))
  # Subsequent calls return ""
  expect_identical(p6$read_all_error(), "")
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
