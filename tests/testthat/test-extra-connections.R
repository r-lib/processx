test_that("writing to extra connection", {
  skip_on_cran()

  msg <- "foobar"
  cmd <- c(get_tool("px"), "echo", "3", "1", nchar(msg))

  pipe <- conn_create_pipepair(nonblocking = c(FALSE, FALSE))

  expect_silent(
    p <- process$new(
      cmd[1],
      cmd[-1],
      stdout = "|",
      stderr = "|",
      connections = list(pipe[[1]])
    )
  )
  close(pipe[[1]])
  on.exit(p$kill(), add = TRUE)

  conn_write(pipe[[2]], msg)
  p$poll_io(-1)
  expect_equal(p$read_all_output_lines(), msg)
  expect_equal(p$read_all_error_lines(), character())
  close(pipe[[2]])
})

test_that("reading from extra connection", {
  skip_on_cran()

  cmd <- c(
    get_tool("px"),
    "sleep",
    "0.5",
    "write",
    "3",
    "foobar\r\n",
    "out",
    "ok"
  )

  pipe <- conn_create_pipepair()

  expect_silent(
    p <- process$new(
      cmd[1],
      cmd[-1],
      stdout = "|",
      stderr = "|",
      connections = list(pipe[[2]])
    )
  )
  close(pipe[[2]])
  on.exit(p$kill(), add = TRUE)

  ## Nothing to read yet
  expect_equal(conn_read_lines(pipe[[1]]), character())

  ## Wait until there is output
  ready <- poll(list(pipe[[1]]), 5000)[[1]]
  expect_equal(ready, "ready")
  expect_equal(conn_read_lines(pipe[[1]]), "foobar")
  expect_equal(p$read_all_output_lines(), "ok")
  expect_equal(p$read_all_error_lines(), character())
  close(pipe[[1]])
})

test_that("reading and writing to extra connection", {
  skip_on_cran()

  msg <- "foobar\n"
  cmd <- c(get_tool("px"), "echo", "3", "4", nchar(msg), "outln", "ok")

  pipe1 <- conn_create_pipepair(nonblocking = c(FALSE, FALSE))
  pipe2 <- conn_create_pipepair()

  expect_silent(
    p <- process$new(
      cmd[1],
      cmd[-1],
      stdout = "|",
      stderr = "|",
      connections = list(pipe1[[1]], pipe2[[2]])
    )
  )
  close(pipe1[[1]])
  close(pipe2[[2]])

  on.exit(p$kill(), add = TRUE)

  conn_write(pipe1[[2]], msg)
  p$poll_io(-1)
  expect_equal(conn_read_chars(pipe2[[1]]), msg)
  expect_equal(p$read_output_lines(), "ok")
  close(pipe1[[2]])
  close(pipe2[[1]])
})

test_that("conn_create_fd()", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeLines("foo", tmp)
  fcon <- conn_create_file(tmp)
  on.exit(close(fcon), add = TRUE)
  fd <- conn_get_fileno(fcon)

  con <- conn_create_fd(fd, close = FALSE)
  on.exit(close(con), add = TRUE)
  expect_true(is_connection(con))
  # On Windows conn_get_fileno() creates a new CRT fd for the HANDLE
  if (!is_windows()) expect_equal(conn_get_fileno(con), fd)
  expect_snapshot(error = TRUE, {
    conn_create_fd("foo")
    conn_create_fd(0L, encoding = 1)
    conn_create_fd(0L, close = NA)
  })
})

test_that("conn_read_bytes()", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeBin(charToRaw("foobar"), tmp)

  con <- conn_create_file(tmp)
  on.exit(close(con), add = TRUE)
  # Reading a file connection is asynchronous on Windows, so the first
  # read may return nothing
  if (!is_windows()) {
    expect_equal(conn_read_bytes(con, 3), charToRaw("foo"))
    expect_equal(processx_conn_read_bytes(con), charToRaw("bar"))
  }
  expect_snapshot(error = TRUE, {
    processx_conn_read_bytes("foo")
    processx_conn_read_bytes(con, "x")
  })
})

test_that("conn_create_file() read/write defaults", {
  # Reading a file connection is asynchronous on Windows, so the first
  # read may return nothing
  skip_on_os("windows")
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)

  con <- conn_create_file(tmp, write = TRUE)
  conn_write(con, "foo")
  close(con)

  con2 <- conn_create_file(tmp, read = TRUE)
  on.exit(close(con2), add = TRUE)
  expect_equal(conn_read_chars(con2), "foo")
})

test_that("conn_disable_inheritance()", {
  expect_silent(conn_disable_inheritance())
})

test_that("is_valid_fd()", {
  expect_true(is_valid_fd(0L))
  expect_false(is_valid_fd(9999L))
  expect_snapshot(error = TRUE, is_valid_fd("foo"))
})
