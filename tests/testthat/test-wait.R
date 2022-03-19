
test_that("no deadlock when no stdout + wait", {

  skip("failure would freeze")

  p <- process$new("seq", c("1", "100000"))
  p$wait()
})

test_that("wait with timeout", {

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "3"))
  expect_true(p$is_alive())

  t1 <- proc.time()
  p$wait(timeout = 100)
  t2 <- proc.time()

  expect_true(p$is_alive())
  expect_true((t2 - t1)["elapsed"] >   50/1000)
  expect_true((t2 - t1)["elapsed"] < 3000/1000)

  p$kill()
  expect_false(p$is_alive())
})

test_that("wait after process already exited", {

  px <- get_tool("px")

  pxs <- replicate(20, process$new(px, c("outln",  "foo", "outln", "bar")))
  rm(pxs)

  p <- process$new(
    px, c("outln", "foo", "outln", "bar", "outln", "foobar"))
  on.exit(p$kill(), add = TRUE)

  ## Make sure it is done
  p$wait()

  ## Now wait() should return immediately, regardless of timeout
  expect_true(system.time(p$wait())[["elapsed"]] < 1)
  expect_true(system.time(p$wait(3000))[["elapsed"]] < 1)
})

test_that("no fd leak on unix", {
  skip_on_cran()
  skip_on_os("solaris")
  if (is_windows()) return(expect_true(TRUE))
  skip_on_covr()

  # We run this test in a subprocess, so we can send an interrupt to it
  # We start a subprocess (within the subprocess) and wait on it.
  # Then the main process, after waiting a second so that everything is
  # set up in the subprocess, sends an interrupt. The suprocess catches
  # this interrupts and copies everything back to the main process.

  rs <- callr::r_session$new()
  on.exit(rs$close(), add = TRUE)

  rs$call(function() {
    fd1 <- ps::ps_num_fds(ps::ps_handle())
    p <- processx::process$new("sleep", "3", poll_connection = FALSE)
    err <- tryCatch(ret <- p$wait(), interrupt = function(e) e)
    fd2 <- ps::ps_num_fds(ps::ps_handle())
    list(fd1 = fd1, fd2 = fd2, err = err)
  })

  Sys.sleep(1)
  rs$interrupt()
  rs$poll_io(1000)
  res <- rs$read()

  expect_equal(res$result$fd1, res$result$fd2)
  expect_s3_class(res$result$err, "interrupt")
})
