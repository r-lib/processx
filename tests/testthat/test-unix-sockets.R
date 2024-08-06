
test_that("CRUD", {
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  expect_equal(
    poll(list(sock1), 10),
    list("timeout")
  )
  expect_equal(conn_unix_socket_state(sock1), "listening")

  if (is_windows()) {
    expect_equal(conn_file_name(sock1), make_pipe_file_name(sock))
  } else {
    expect_equal(conn_file_name(sock1), sock)
  }

  pr <- poll(list(sock1), 1)
  expect_equal(pr, list("timeout"))

  sock2 <- conn_connect_unix_socket(sock)
  expect_equal(conn_unix_socket_state(sock2), "connected_client")

  pr <- poll(list(sock1), 0)
  expect_equal(pr, list("connect"))
  expect_equal(conn_unix_socket_state(sock1), "listening")

  conn_accept_unix_socket(sock1)
  expect_equal(conn_unix_socket_state(sock1), "connected_server")

  expect_error(conn_accept_unix_socket(sock1), "Socket is not listening")

  pr <- poll(list(sock1, sock2), 1)
  expect_equal(pr, list("timeout", "timeout"))

  conn_write(sock1, "hello\n")
  pr <- poll(list(sock1, sock2), 1)
  expect_equal(pr, list("silent", "ready"))

  conn_write(sock2, "hello there\n")
  pr <- poll(list(sock1, sock2), 1)
  expect_equal(pr, list("ready", "ready"))

  msg1 <- conn_read_lines(sock1)
  msg2 <- conn_read_lines(sock2)
  expect_equal(msg1, "hello there")
  expect_equal(msg2, "hello")

  pr <- poll(list(sock1, sock2), 1)
  expect_equal(pr, list("timeout", "timeout"))

  close(sock2)
  expect_equal(conn_read_chars(sock1), "")
  expect_false(conn_is_incomplete(sock1))
  close(sock1)
})

test_that("client can read / write before accept", {
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)

  expect_equal(conn_read_chars(sock2), "")
  expect_equal(conn_read_lines(sock2), character())
  expect_equal(conn_write(sock2, "hello\n"), raw(0))

  conn_accept_unix_socket(sock1)
  expect_equal(poll(list(sock1), 0), list("ready"))
  expect_equal(conn_read_lines(sock1), "hello")
  close(sock1)
  close(sock2)
})

test_that("poll returns connect", {
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)

  pr <- poll(list(sock1), 0)
  expect_equal(pr, list("connect"))
  close(sock1)
  close(sock2)
})

test_that("poll returns connect even if pipes are connected", {
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)
  pr <- poll(list(sock1), 0)
  expect_equal(pr, list("connect"))
  close(sock1)
  close(sock2)
})

test_that("reading unaccepted server socket is error", {
  # but maybe not on Windows: TODO
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)
  expect_equal(
    poll(list(sock1), 3000),
    list("connect")
  )

  expect_error(conn_read_chars(sock1))

  close(sock1)
  close(sock2)
})

test_that("writing unaccepted server socket is error", {
  # but maybe not on Windows: TODO
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)
  expect_equal(
    poll(list(sock1), 3000),
    list("connect")
  )

  expect_error(conn_write(sock1, "Hello\n"))

  close(sock1)
  close(sock2)
})

test_that("here is no extra ready for poll(), without data", {
  # on Widows
  skip_on_cran()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)
  sock2 <- conn_connect_unix_socket(sock)
  conn_write(sock2, "hello boss\n")

  pr <- poll(list(sock1), 0)
  expect_equal(pr, list("connect"))

  conn_accept_unix_socket(sock1)
  expect_equal(
    conn_read_lines(sock1),
    "hello boss"
  )

  close(sock1)
  close(sock2)
})

test_that("closing the other end finishes `poll()`, on macOS", {
  skip_on_cran()
  # seems fragile in covr
  skip_on_covr()

  sock <- tempfile()
  on.exit(unlink(sock), add = TRUE)
  if (is_windows()) sock <- basename(sock)

  sock1 <- conn_create_unix_socket(sock)

  connect <- function(sock) {
    sock2 <- processx::conn_connect_unix_socket(sock)
    processx::conn_write(sock2, "hello boss\n")
    processx::poll(list(sock2), 3000)
    ret <- processx::conn_read_lines(sock2)
    close(sock2)
    ret
  }

  client <- callr::r_bg(connect, args = list(sock = sock))
  on.exit(client$kill(), add = TRUE)

  pr <- poll(list(sock1), 2000)
  expect_equal(pr, list("connect"))
  conn_accept_unix_socket(sock1)

  pr <- poll(list(sock1), 2000)
  expect_equal(pr, list("ready"))
  lines <- conn_read_lines(sock1)
  expect_equal(lines, "hello boss")
  conn_write(sock1, "hello you\n")

  pr <- poll(list(sock1), 2000)
  expect_equal(pr, list("ready"))
  expect_equal(conn_read_chars(sock1), "")
  expect_false(conn_is_incomplete(sock1))
  close(sock1)

  client$wait(2000)
  expect_false(client$is_alive())
  expect_equal(client$get_result(), "hello you")
})

test_that("errors", {
  skip_on_cran()

  if (!is_windows()) {
    sock <- file.path(tempdir(), strrep(basename(tempfile()), 1000))
    expect_error(conn_create_unix_socket(sock))
    expect_error(conn_create_unix_socket("/dev/null"))
    expect_error(conn_connect_unix_socket("/dev/null"))
  }

  ff <- conn_create_fifo()
  expect_error(conn_accept_unix_socket(ff))

  expect_error(conn_unix_socket_state(ff))
})

test_that("unix-sockets.h", {
  skip_on_cran()

  sock <- get_tool("sock")
  server <- conn_create_unix_socket()
  on.exit(close(server), add = TRUE)
  on.exit(unlink(conn_file_name(server)), add = TRUE)

  args <- conn_file_name(server)
  if (is_windows()) {
    args <- basename(args)
  }
  client <- process$new(sock, args, stdout = "|", stderr = "|")
  pr <- poll(list(server), 3000)
  expect_true(client$is_alive())
  expect_equal(pr, list("connect"))

  conn_accept_unix_socket(server)
  expect_equal(
    conn_write(server, "hello brother"),
    raw(0)
  )

  pr <- poll(list(server), 3000)
  expect_equal(pr, list("ready"))
  expect_equal(
    conn_read_chars(server),
    "hello there!"
  )

  poll(list(server), 3000)
  expect_equal(pr, list("ready"))

  expect_equal(
    conn_read_chars(server),
    ""
  )
  expect_false(
    conn_is_incomplete(server)
  )

  expect_false(client$is_alive())
})
