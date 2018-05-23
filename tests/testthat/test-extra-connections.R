
context("extra connections")

test_that("writing to extra connection", {

  skip_on_cran()

  if (os_type() == "unix")  {
    skip_if_no_tool("bash")
    cmd <- c("bash", "-c", "read -t 5 line <&3; echo $line")
  } else {
    cmd <- c(get_tool("px"), "echo", "3", "1", "7")
  }

  pipe <- conn_create_pipepair()

  expect_silent(
    p <- process$new(cmd[1], cmd[-1],
      stdout = "|", stderr = "|", connections = list(pipe[[1]])
    )
  )

  on.exit(p$kill())

  conn_write(pipe[[2]], "foobar\n")
  p$poll_io(-1)
  expect_equal(p$read_all_output_lines(), "foobar")
  expect_equal(p$read_all_error_lines(), character())
})

test_that("reading from extra connection", {

  skip_on_cran()

  if (os_type() == "unix") {
    skip_if_no_tool("bash")
    cmd <- c("bash", "-c", "sleep .5; echo foobar >&3; echo ok")
  } else {
    cmd <- c(get_tool("px"), "sleep", "1", "write", "3", "foobar\r\n", "out", "ok")
  }

  pipe <- conn_create_pipepair()

  on.exit(p$kill())
  expect_silent(
    p <- process$new(cmd[1], cmd[-1], stdout = "|", stderr = "|",
      connections = list(pipe[[2]])
    )
  )

  ## Nothing to read yet
  expect_equal(conn_read_lines(pipe[[1]]), character())

  ## Wait until there is output
  p$poll_io(-1)
  expect_equal(conn_read_lines(pipe[[1]]), "foobar")
  expect_equal(p$read_all_output_lines(), "ok")
  expect_equal(p$read_all_error_lines(), character())
})

test_that("reading and writing to extra connection", {

  skip_on_cran()
  if (os_type() == "unix") {
    skip_if_no_tool("bash")
    cmd <- c("bash", "-c", "read -t 1000 line <&3; echo $line >&4; echo ok")
  } else {
    cmd <- c(get_tool("px"), "echo", "3", "4", "7", "outln", "ok")
  }

  pipe1 <- conn_create_pipepair()
  pipe2 <- conn_create_pipepair()

  expect_silent(
    p <- process$new(cmd[1], cmd[-1], stdout = "|", stderr = "|",
      connections = list(pipe1[[1]], pipe2[[2]])
    )
  )

  on.exit(p$kill())

  conn_write(pipe1[[2]], "foobar\n")
  p$poll_io(-1)
  expect_equal(conn_read_lines(pipe2[[1]]), "foobar")
  expect_equal(p$read_output_lines(), "ok")
})
