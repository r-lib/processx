
context("print")

test_that("print", {

  cmd <- sleep(5, commandline = FALSE)
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
  p <- process$new(commandline = sleep(5))
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
