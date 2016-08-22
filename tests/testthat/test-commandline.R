
context("commandline")

test_that("One of command & commandline or error", {

  expect_error(
    process$new("sleep", "5", "sleep 5"),
    "exactly one of"
  )

  expect_error(
    process$new(commandline = "sleep 5", args = "5"),
    "Omit 'args' when 'commandline' is specified"
  )
})

test_that("'commandline' works", {

  skip_on_cran()

  win  <- "(echo kuku) && (>&2 echo kuku2) && (ping -n 2 127.0.0.1 > NUL)"
  unix <- "echo kuku; >&2 echo kuku2; sleep 1"

  p <- process$new(
    commandline = if (os_type() == "windows") win else unix,
    stdout = TRUE,
    stderr = TRUE
  )
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  expect_true(p$is_alive())

  p$wait()

  expect_equal(p$read_output_lines(), "kuku")
  expect_equal(p$read_error_lines(), "kuku2")
})
