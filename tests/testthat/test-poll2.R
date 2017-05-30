
context("poll multiple processes")

test_that("single process", {
  cmd <- switch(
    os_type(),
    "unix" = "sleep 1; ls",
    "ping -n 2 127.0.0.1 && dir /b"
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
  cmd1 <- switch(
    os_type(),
    "unix" = "sleep 1; ls",
    "ping -n 2 127.0.0.1 && dir /b"
  )
  cmd2 <- switch(
    os_type(),
    "unix" = "sleep 2; ls 1>&2",
    "ping -n 2 127.0.0.1 && dir /b 1>&2"
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
