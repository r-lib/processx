
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
  con <- p$get_output_connection()

  p$poll_io(-1)
  expect_equal(readChar(con, 1), "1")
  expect_equal(readChar(con, 1), "2")
  expect_equal(readChar(con, 1), "3")
  expect_equal(readChar(con, 1), "\n")
})

test_that("Can read multiple characters", {

  cmd <- if (os_type() == "unix") {
    "printf 123456789"
  } else {
    "<nul set /p =123456789"
  }

  p <- process$new(commandline = cmd, stdout = "|")
  p$wait()
  con <- p$get_output_connection()

  p$poll_io(-1)
  expect_equal(readChar(con, 3), "123")
  expect_equal(readChar(con, 4), "4567")
  expect_equal(readChar(con, 2), "89")
  expect_equal(readChar(con, 10), "\n")
})
