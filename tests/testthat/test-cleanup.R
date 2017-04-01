
context("Cleanup")

test_that("process is cleaned up", {

  p <- process$new(commandline = sleep(60), cleanup = TRUE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_false(process__exists(pid))
})

test_that("process can stay alive", {

  on.exit(tools::pskill(pid), add = TRUE)
  p <- process$new(commandline = sleep(60), cleanup = FALSE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_true(process__exists(pid))
})
