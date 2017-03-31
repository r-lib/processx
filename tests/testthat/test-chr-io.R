
context("character IO")

test_that("Can read last line without trailing newline", {
  skip_other_platforms("unix")

  p <- process$new(commandline = "printf foobar", stdout = "|")
  p$wait()
  expect_equal(p$read_output_lines(), "foobar")
})

test_that("Can read single characters", {
  skip_other_platforms("unix")
  p <- process$new(commandline = "printf 123", stdout = "|")
  p$wait()
  con <- p$get_output_connection()

  expect_equal(readChar(con, 1), "1")
  expect_equal(readChar(con, 1), "2")
  expect_equal(readChar(con, 1), "3")
  expect_equal(readChar(con, 1), "\n")
})

test_that("Can read multiple characters", {
  skip_other_platforms("unix")
  p <- process$new(commandline = "printf 123456789", stdout = "|")
  p$wait()
  con <- p$get_output_connection()

  expect_equal(readChar(con, 3), "123")
  expect_equal(readChar(con, 4), "4567")
  expect_equal(readChar(con, 2), "89")
  expect_equal(readChar(con, 10), "\n")
})
