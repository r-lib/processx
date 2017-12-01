
context("print")

test_that("print", {

  cmd <- sleep(5)
  p <- process$new(cmd[1], cmd[-1])
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  expect_output(
    print(p),
    "PROCESS .* running, pid"
  )

  p$kill()
  expect_output(
    print(p),
    "PROCESS .* finished"
  )
})

test_that("print, commandline", {
  skip_on_cran()
  p <- process$new(commandline = paste(sleep(1), collapse = " "))
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  expect_output(
    print(p),
    "PROCESS .* running, pid"
  )

  p$kill()
  expect_output(
    print(p),
    "PROCESS .* finished"
  )
})
