
context("poll multiple processes")

test_that("single process", {
  skip_on_cran()
  cmd <- switch(
    os_type(),
    "unix" = "sleep 1; ls",
    paste0(paste(sleep(1), collapse = " "), " && dir /b")
  )
  p <- process$new(commandline = cmd, stdout = "|")

  ## Timeout
  expect_equal(
    poll(list(p), 0),
    list(c(output = "timeout", error = "nopipe"))
  )

  p$wait()
  expect_equal(
    poll(list(p), -1),
    list(c(output = "ready", error = "nopipe"))
  )

  p$read_output_lines()
  expect_equal(
    poll(list(p), -1),
    list(c(output = "ready", error = "nopipe"))
  )

  p$kill()
  expect_equal(
    poll(list(p), -1),
    list(c(output = "ready", error = "nopipe"))
  )

  close(p$get_output_connection())
  expect_equal(
    poll(list(p), -1),
    list(c(output = "closed", error = "nopipe"))
  )
})

test_that("multiple processes", {
  skip_on_cran()
  cmd1 <- switch(
    os_type(),
    "unix" = "sleep 1; ls",
    paste0(paste(sleep(1), collapse = " "), " && dir /b")
  )
  cmd2 <- switch(
    os_type(),
    "unix" = "sleep 2; ls 1>&2",
    paste0(paste(sleep(1), collapse = " "), " && dir /b 1>&2")
  )

  p1 <- process$new(commandline = cmd1, stdout = "|")
  p2 <- process$new(commandline = cmd2, stderr = "|")

  ## Timeout
  res <- poll(list(p1 = p1, p2 = p2), 0)
  expect_equal(
    res,
    list(
      p1 = c(output = "timeout", error = "nopipe"),
      p2 = c(output = "nopipe", error = "timeout")
    )
  )

  p1$wait()
  res <- poll(list(p1 = p1, p2 = p2), -1)
  expect_equal(res$p1, c(output = "ready", error = "nopipe"))
  expect_equal(res$p2[["output"]], "nopipe")
  expect_true(res$p2[["error"]] %in% c("silent", "ready"))

  close(p1$get_output_connection())
  p2$wait()
  res <- poll(list(p1 = p1, p2 = p2), -1)
  expect_equal(
    res,
    list(
      p1 = c(output = "closed", error = "nopipe"),
      p2 = c(output = "nopipe", error = "ready")
    )
  )

  close(p2$get_error_connection())
  res <- poll(list(p1 = p1, p2 = p2), 0)
  expect_equal(
    res,
    list(
      p1 = c(output = "closed", error = "nopipe"),
      p2 = c(output = "nopipe", error = "closed")
    )
  )

})

test_that("multiple polls", {

  skip_on_cran()
  if (os_type() != "unix") skip("Only on Unix")

  cmd <- "sleep 1; echo foo; sleep 1; echo bar"

  p <- process$new(commandline = cmd, stdout = "|", stderr = "|")

  out <- character()
  while (p$is_alive()) {
    poll(list(p), 2000)
    out <- c(out, p$read_output_lines())
  }

  expect_identical(out, c("foo", "bar"))
})

test_that("polling and buffering", {

  if (os_type() != "unix") skip("Only on Unix")

  ## We set up two processes, one produces a output, that we do not
  ## read out from the cache. The other one does not produce output.

  p1 <- process$new("seq", c("1", "20"), stdout = "|")
  p2 <- process$new("sleep", "4", stdout = "|")
  on.exit(p1$kill(), add = TRUE)
  on.exit(p2$kill(), add = TRUE)

  ## We poll until p1 has output. We read out some of the output,
  ## and leave the rest in the buffer.
  p1$poll_io(-1)
  expect_equal(p1$read_output_lines(n = 2), c("1", "2"))

  ## Now poll should return immediately, because there is output ready
  ## from p1. The status of p2 should be 'silent' (and not 'timeout')
  tick <- Sys.time()
  s <- poll(list(p1, p2), 5000)
  expect_equal(
    s,
    list(
      c(output = "ready", error = "nopipe"),
      c(output = "silent", error = "nopipe")
    )
  )

  ## Check that poll has returned immediately
  expect_true(Sys.time() - tick < as.difftime(2, units = "secs"))
})

test_that("polling and buffering #2", {

  if (os_type() != "unix") skip("Only on Unix")

  ## We run this a bunch of times, because it used to fail
  ## non-deterministically on the CI
  for (i in 1:100) {

    ## Two processes, they both produce output. For the first process,
    ## we make sure that there is something in the buffer.
    ## For the second process we need to poll, but data should be
    ## available immediately.
    p1 <- process$new("seq", c("1", "20"), stdout = "|")
    p2 <- process$new("seq", c("21", "30"), stdout = "|")
    on.exit(p1$kill(), add = TRUE)
    on.exit(p2$kill(), add = TRUE)

    ## We poll until p1 has output. We read out some of the output,
    ## and leave the rest in the buffer.
    p1$poll_io(-1)
    expect_equal(p1$read_output_lines(n = 2), c("1", "2"))

    ## Now poll should return ready for both processes, and it should
    ## return fast.
    tick <- Sys.time()
    s <- poll(list(p1, p2), 5000)
    expect_equal(
      s,
      list(
        c(output = "ready", error = "nopipe"),
        c(output = "ready", error = "nopipe")
      )
    )

    ## Check that poll has returned immediately
    expect_true(Sys.time() - tick < as.difftime(2, units = "secs"))
  }
})
