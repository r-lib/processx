
context("Cleanup")

test_that("process is cleaned up", {

  p <- process$new(commandline = sleep(60), cleanup = TRUE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_false(process__exists(pid))
})

test_that("process can stay alive", {

  ## We cannot use 'commandline' because then there is an intermediate
  ## shell, and we cannot clean up the ping process with tools::pskill
  cmd <- sleep(60, commandline = FALSE)

  on.exit(tools::pskill(pid, 9), add = TRUE)
  p <- process$new(cmd[1], cmd[-1], cleanup = FALSE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_true(process__exists(pid))
})
