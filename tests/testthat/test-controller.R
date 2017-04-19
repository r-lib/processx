
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

  ## NEed bash for the -t option
  if (Sys.which("bash") == "") skip("Needs bash")

  ## Check that we can write / read the control channel
  expect_silent(
    p <- process$new(
      "bash", c("-c", "read -t 3 line <&4; echo $line >&3"),
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

test_that("child inherits fds, can read, write, windows", {

  skip_other_platforms("windows")

  expect_silent(
    p <- process$new("fixtures/puppet.exe", controller = TRUE,
                     stdout = "|", stderr = "|")
  )

  Sys.sleep(0.1);
  p$write_control(charToRaw("hello!\n"))

  ans <- ""
  while (p$is_incomplete_control()) {
    ans <- paste0(ans, rawToChar(p$read_control()))
  }
  expect_identical(ans, "hello!\n")

  p$wait()
  expect_identical(p$read_output_lines(), "Read 7 bytes")
  expect_identical(p$read_error_lines(), character())
  expect_identical(p$get_exit_status(), 0L);
})

test_that("non-blocking reads in the child, windows", {

  skip_other_platforms("windows")

  expect_silent(
    p <- process$new("fixtures/puppet.exe", controller = TRUE,
                     stdout = "|", stderr = "|")
  )

  Sys.sleep(0.1);
  p$write_control(charToRaw("hel"))
  Sys.sleep(0.1);
  p$write_control(charToRaw("lo!\n"))

  ans <- ""
  while (p$is_incomplete_control()) {
    ans <- paste0(ans, rawToChar(p$read_control()))
  }
  expect_identical(ans, "hello!\n")

  p$wait()
  expect_identical(p$read_output_lines(), "Read 7 bytes")
  expect_identical(p$read_error_lines(), character())
  expect_identical(p$get_exit_status(), 0L);
})

test_that("polling the control connection", {

  skip_other_platforms("unix")

  t1 <- Sys.time()
  expect_silent(
    p <- process$new(
      "sh", c("-c", "sleep 1;echo foobar >&3"),
      stdout = "|", stderr = "|", controller = TRUE
    )
  )

  expect_equal(p$poll_control(10), "timeout")
  expect_equal(p$poll_control(2000), "ready")

  expect_true(Sys.time() - t1 > as.difftime(1, units = "secs"))

  ans <- ""
  while (p$is_incomplete_control()) {
    ans <- paste0(ans, rawToChar(p$read_control()))
  }
  expect_identical(ans, "foobar\n");
})

test_that("polling the control connection, windows", {

  skip_other_platforms("windows")

  t1 <- Sys.time()
  expect_silent(
    p <- process$new("fixtures/puppet.exe", args = "-w", controller = TRUE,
                     stdout = "|", stderr = "|")
  )

  expect_equal(p$poll_control(10), "timeout")
  expect_equal(p$poll_control(2000), "ready")

  expect_true(Sys.time() - t1 > as.difftime(1, units = "secs"))

  ans <- ""
  while (p$is_incomplete_control()) {
    ans <- paste0(ans, rawToChar(p$read_control()))
  }
  expect_identical(ans, "foobar\n");
})
