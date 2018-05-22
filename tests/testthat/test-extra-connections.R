
context("extra connections")

test_that("writing to extra connection", {

  skip_on_cran()
  skip_other_platforms("unix")
  skip_if_no_tool("bash")

  pipe <- conn_create_pipepair()

  expect_silent(
    p <- process$new(
      "bash", c("-c", "read -t 1000 line <&3; echo $line"),
      stdout = "|", stderr = "|", connections = list(pipe[[2]])
    )
  )

  on.exit(p$kill())

  conn_write(pipe[[1]], "foobar\n")
  p$poll_io(-1)
  expect_equal(p$read_output_lines(), "foobar")
})

test_that("reading from extra connection", {

  skip_on_cran()
  skip_other_platforms("unix")
  skip_if_no_tool("bash")

  pipe <- conn_create_pipepair()

  on.exit(p$kill())
  expect_silent(
    p <- process$new(
      "bash", c("-c", "sleep .5; echo foobar >&3; echo ok"),
      stdout = "|", stderr = "|", connections = list(pipe[[2]])
    )
  )

  ## Nothing to read yet
  expect_equal(conn_read_lines(pipe[[1]]), character())

  ## Wait until there is output
  p$poll_io(-1)
  expect_equal(conn_read_lines(pipe[[1]]), "foobar")
  expect_equal(p$read_output_lines(), "ok")
})

test_that("reading and writing to extra connection", {

  skip_on_cran()
  skip_other_platforms("unix")
  skip_if_no_tool("bash")

  pipe1 <- conn_create_pipepair()
  pipe2 <- conn_create_pipepair()

  expect_silent(
    p <- process$new(
      "bash", c("-c", "read -t 1000 line <&3; echo $line >&4; echo ok"),
      stdout = "|", stderr = "|", connections = list(pipe1[[2]], pipe2[[1]])
    )
  )

  on.exit(p$kill())

  conn_write(pipe1[[1]], "foobar\n")
  p$poll_io(-1)
  expect_equal(conn_read_lines(pipe2[[2]]), "foobar")
  expect_equal(p$read_output_lines(), "ok")
})
