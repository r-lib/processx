
context("set std streams")

test_that("setting stdout to a file", {
  stdout_to_file <- function(filename) {
    con <- processx::conn_create_file(filename, write = TRUE)
    processx::conn_set_stdout(con)
    cat("output\n")
    message("error")
    close(con)
    42
  }

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  opt <- callr::r_process_options(
    func = stdout_to_file,
    args = list(filename = tmp))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_error_lines(), "error")
  expect_equal(p$read_all_output_lines(), character())
  expect_equal(readLines(tmp), "output")
})

test_that("setting stderr to a file", {
  stderr_to_file <- function(filename) {
    con <- processx::conn_create_file(filename, write = TRUE)
    processx::conn_set_stderr(con)
    cat("output\n")
    message("error")
    close(con)
    42
  }

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  opt <- callr::r_process_options(
    func = stderr_to_file,
    args = list(filename = tmp))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_output_lines(), "output")
  expect_equal(p$read_all_error_lines(), character())
  expect_equal(readLines(tmp), "error")
})

test_that("setting stdout multiple times", {
  stdout_to_file <- function(file1, file2) {
    con1 <- processx::conn_create_file(file1, write = TRUE)
    processx::conn_set_stdout(con1)
    cat("output\n")
    message("error")
    close(con1)

    con2 <- processx::conn_create_file(file2, write = TRUE)
    processx::conn_set_stdout(con2)
    cat("output2\n")
    message("error2")
    close(con2)

    42
  }

  tmp1 <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp1, tmp2)), add = TRUE)
  opt <- callr::r_process_options(
    func = stdout_to_file,
    args = list(file1 = tmp1, file2 = tmp2))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_error_lines(), c("error", "error2"))
  expect_equal(p$read_all_output_lines(), character())
  expect_equal(readLines(tmp1), "output")
  expect_equal(readLines(tmp2), "output2")
})

test_that("set stdout to a pipe", {
  rem_fun <- function() {
    pipe <- processx::conn_create_pipepair()
    processx::conn_set_stdout(pipe[[2]])
    cat("output\n")
    flush(stdout())
    processx::conn_read_lines(pipe[[1]])
  }

  opt <- callr::r_process_options(func = rem_fun)
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), "output")
})

test_that("set stderr to a pipe", {
  rem_fun <- function() {
    pipe <- processx::conn_create_pipepair()
    processx::conn_set_stderr(pipe[[2]])
    message("error")
    flush(stderr())
    processx::conn_read_lines(pipe[[1]])
  }

  opt <- callr::r_process_options(func = rem_fun)
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), "error")
})

test_that("set stdout and save the old fd", {
  stdout <- function(file1, file2) {
    con1 <- processx::conn_create_file(file1, write = TRUE)
    con2 <- processx::conn_create_file(file2, write = TRUE)
    processx::conn_set_stdout(con1)
    cat("output1\n")
    old <- processx::conn_set_stdout(con2, drop = FALSE)
    cat("output2\n")
    processx::conn_set_stdout(old)
    cat("output1 again\n")
    42
  }

  tmp1 <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp1, tmp2)), add = TRUE)
  opt <- callr::r_process_options(
    func = stdout,
    args  = list(file1 = tmp1, file2 = tmp2))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), 42)
  expect_equal(readLines(tmp1), c("output1", "output1 again"))
  expect_equal(readLines(tmp2), "output2")
})

test_that("set stderr and save the old fd", {
  stderr <- function(file1, file2) {
    con1 <- processx::conn_create_file(file1, write = TRUE)
    con2 <- processx::conn_create_file(file2, write = TRUE)
    processx::conn_set_stderr(con1)
    message("output1")
    old <- processx::conn_set_stderr(con2, drop = FALSE)
    message("output2")
    processx::conn_set_stderr(old)
    message("output1 again")
    42
  }

  tmp1 <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp1, tmp2)), add = TRUE)
  opt <- callr::r_process_options(
    func = stderr,
    args  = list(file1 = tmp1, file2 = tmp2))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill())
  expect_equal(p$get_result(), 42)
  expect_equal(readLines(tmp1), c("output1", "output1 again"))
  expect_equal(readLines(tmp2), "output2")
})
