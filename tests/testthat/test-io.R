
context("io")

test_that("We can get the output", {

  skip_on_cran()
  skip_other_platforms("unix")
  skip_without_command("ls")

  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp), add = TRUE)
  cat("foo", file = file.path(tmp, "foo"))
  cat("bar", file = file.path(tmp, "bar"))

  p <- process$new("ls", shQuote(tmp), stdout = TRUE)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()
  out <- sort(p$read_output_lines())
  expect_identical(out, c("bar", "foo"))
})

test_that("We can get the error stream", {

  skip_on_cran()
  skip_other_platforms("unix")

  tmp <- tempfile(fileext = ".sh")
  on.exit(unlink(tmp), add = TRUE)

  cat(">&2 echo hello", ">&2 echo world", sep = "\n", file = tmp)
  Sys.chmod(tmp, "700")

  p <- process$new(tmp, stderr = TRUE)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  p$wait()
  out <- sort(p$read_error_lines())
  expect_identical(out, c("hello", "world"))
})
