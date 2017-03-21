
context("process")

test_that("process works", {

  win  <- c("ping", "-n", "6", "127.0.0.1")
  unix <- c("sleep", "5")
  cmd <- if (os_type() == "windows") win else unix

  p <- process$new(cmd[1], cmd[-1])
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  Sys.sleep(.1)
  expect_true(p$is_alive())
})

test_that("children are removed on kill()", {

  skip("get_pid_by_name not implemented")

  ## tmp1 will call tmp2, and we'll start tmp1 from process$new
  ## Then we kill the process and see if tmp2 was removed as well
  tmp1 <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp1), add = TRUE)

  tmp2 <- tempfile(fileext = ".bat")
  on.exit(unlink(tmp2), add = TRUE)

  if (os_type() == "windows") {
    cat("cmd /c ", shQuote(tmp2), "\n", sep = "", file = tmp1)
    cat("ping -n 61 127.0.0.1\n", file = tmp2)

  } else {
    cat("sh ", tmp2, "\n", sep = "", file = tmp1)
    cat("sleep 60\n", file = tmp2)
  }

  Sys.chmod(tmp1, "700")
  Sys.chmod(tmp2, "700")

  p <- process$new(tmp1)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  ## Wait until everything surely starts
  Sys.sleep(1)

  ## Child should be alive now
  pid <- get_pid_by_name(basename(tmp2))
  expect_true(!is.null(pid))

  ## Kill the process
  p$kill()

  ## Check on the child
  pid <- get_pid_by_name(basename(tmp2))

  ## If alive, then kill it
  if (!is.null(pid)) pskill(pid)

  ## But it should not have been alive
  expect_null(pid)
})

test_that("process is cleaned up on GC", {

  skip("get_pid_by_name not implemented")

  win  <- c("ping", "-n", "6", "127.0.0.1")
  unix <- c("sleep", "5")
  cmd <- if (os_type() == "windows") win else unix

  p <- process$new(cmd[1], cmd[-1])

  expect_true(p$is_alive())

  ## Remove reference and see the process die
  ## We check for the internal name
  name <- p$.__enclos_env__$private$name
  rm(p)
  gc()

  expect_null(get_pid_by_name(name))
})

test_that("get_exit_status", {
  cmd <- if (os_type() == "windows") {
    "cmd /c exit 1"
  } else {
    "echo alive && exit 1"
  }
  p <- process$new(commandline = cmd)
  p$wait()
  expect_identical(p$get_exit_status(), 1L)
})

test_that("restart", {

  p <- process$new(commandline = sleep(5))
  expect_true(p$is_alive())

  p$kill(grace = 0)

  expect_false(p$is_alive())

  p$restart()
  expect_true(p$is_alive())

  p$kill(grace = 0)
})
