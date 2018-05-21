
context("stdin")

test_that("stdin", {

  skip_on_cran()
  skip_if_no_tool("cat")

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  p <- process$new("cat", stdin = "|", stdout = tmp, stderr = "|")
  expect_true(p$is_alive())

  p$write_input("foo\n")
  p$write_input("bar\n")
  expect_true(p$is_alive())

  close(p$get_input_connection())
  p$wait(5000)
  expect_false(p$is_alive())
  p$kill()

  expect_equal(readLines(tmp), c("foo", "bar"))
})

test_that("stdin & stdout", {

  skip_on_cran()
  skip_if_no_tool("cat")

  p <- process$new("cat", stdin = "|", stdout = "|")
  expect_true(p$is_alive())

  p$write_input("foo\n")
  p$poll_io(1000)
  expect_equal(p$read_output_lines(), "foo")

  p$write_input("bar\n")
  p$poll_io(1000)
  expect_equal(p$read_output_lines(), "bar")

  close(p$get_input_connection())
  p$wait(10)
  expect_false(p$is_alive())
  p$kill()
})

test_that("stdin buffer full", {

  skip_on_cran()
  skip_other_platforms("unix")

  px <- get_tool("px")
  p <- process$new(px, c("sleep", 100), stdin = "|")
  for (i in 1:100000) {
    ret <- p$write_input("foobar")
    if (length(ret) > 0) break
  }

  expect_true(length(ret) > 0)
})

test_that("file as stdin", {

  skip_on_cran()
  skip_if_no_tool("cat")

  tmp <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp, tmp2), recursive = TRUE), add = TRUE)

  txt <- strrep(paste(sample(letters, 10), collapse = ""), 100)
  cat(txt, file = tmp)

  p <- process$new("cat", stdin = tmp, stdout = tmp2)
  p$wait()
  expect_true(file.exists(tmp2))
  expect_equal(readChar(tmp2, nchar(txt)), txt)
})

test_that("large file as stdin", {

  skip_on_cran()
  skip_if_no_tool("cat")

  tmp <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp, tmp2), recursive = TRUE), add = TRUE)

  txt <- strrep(paste(sample(letters, 10), collapse = ""), 10000)
  cat(txt, file = tmp)

  p <- process$new("cat", stdin = tmp, stdout = tmp2)
  p$wait()
  expect_true(file.exists(tmp2))
  expect_equal(file.info(tmp2)$size, nchar(txt))
})

test_that("writing raw", {
  skip_on_cran()
  skip_if_no_tool("cat")

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  p <- process$new("cat", stdin = "|", stdout = tmp, stderr = "|")
  expect_true(p$is_alive())

  foo <- charToRaw("foo\n")
  bar <- charToRaw("bar\n")
  p$write_input(foo)
  p$write_input(bar)
  expect_true(p$is_alive())

  close(p$get_input_connection())
  p$wait(5000)
  expect_false(p$is_alive())
  p$kill()

  expect_equal(readLines(tmp), c("foo", "bar"))
})
