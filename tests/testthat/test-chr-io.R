
context("character IO")

test_that("Can read last line without trailing newline", {

  cmd <- if (os_type() == "unix") {
    "printf foobar"
  } else {
    "<nul set /p =foobar"
  }

  p <- process$new(commandline = cmd, stdout = "|")
  out <- p$read_all_output_lines()
  expect_equal(out, "foobar")
})

test_that("Can read single characters", {

  cmd <- if (os_type() == "unix") {
    "printf 123"
  } else {
    "<nul set /p =123"
  }

  p <- process$new(commandline = cmd, stdout = "|")
  p$wait()

  p$poll_io(-1)
  expect_equal(p$read_output(1), "1")
  expect_equal(p$read_output(1), "2")
  expect_equal(p$read_output(1), "3")
  expect_equal(p$read_output(1), "")
  expect_false(p$is_incomplete_output())
})

test_that("Can read multiple characters", {

  cmd <- if (os_type() == "unix") {
    "printf 123456789"
  } else {
    "<nul set /p =123456789"
  }

  p <- process$new(commandline = cmd, stdout = "|")
  p$wait()

  p$poll_io(-1)
  expect_equal(p$read_output(3), "123")
  expect_equal(p$read_output(4), "4567")
  expect_equal(p$read_output(2), "89")
  expect_equal(p$read_output(1), "")
  expect_false(p$is_incomplete_output())
})
