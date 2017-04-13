
context("controller")

test_that("child inherits fds", {

  skip_other_platforms("unix")

  ## This is just to check that the file descriptors are OK
  expect_silent(
    p <- process$new(
      "sh", c("-c", "read line <&4; echo $line >&3"),
      stdout = "|", stderr = "|", controller = TRUE
    )
  )

  expect_identical(p$read_output_lines(), character())
  expect_identical(p$read_error_lines(), character())
})

test_that("simple echo using bash", {

  skip_other_platforms("unix")

  ## Check that we can write / read the control channel
  expect_silent(
    p <- process$new(
      "sh", c("-c", "read -t 3 line <&4; echo $line >&3"),
      stdout = "|", stderr = "|", controller = TRUE
    )
  )

  p$write_control(charToRaw("hello!\n"))
  ans <- ""
  while (p$is_incomplete_control()) {
    ans <- paste0(ans, rawToChar(p$read_control()))
  }

  expect_identical(ans, "hello!\n")

  p$poll_io(-1)
  expect_identical(p$read_output_lines(), character())
  expect_identical(p$read_error_lines(), character())
  expect_identical(p$get_exit_status(), 0L)
})
