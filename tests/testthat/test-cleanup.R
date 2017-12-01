
context("Cleanup")

test_that("process is cleaned up", {

  cmd <- sleep(1)
  p <- process$new(cmd[1], cmd[-1], cleanup = TRUE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_false(process__exists(pid))
})

test_that("process can stay alive", {

  cmd <- sleep(60)

  on.exit(tools::pskill(pid, 9), add = TRUE)
  p <- process$new(cmd[1], cmd[-1], cleanup = FALSE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_true(process__exists(pid))
})
