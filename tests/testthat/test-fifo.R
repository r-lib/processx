
test_that("read end first", {
  skip_on_cran()

  fifo <- tempfile()
  on.exit(unlink(fifo), add = TRUE)
  if (is_windows()) fifo <- basename(fifo)

  reader <- conn_create_fifo(fifo)
  expect_equal(
    poll(list(reader), 10),
    list("timeout")
  )
  expect_true(conn_is_incomplete(reader))
  expect_true(ends_with(conn_file_name(reader), basename(fifo)))

  writer <- conn_connect_fifo(fifo, write = TRUE)
  expect_true(ends_with(conn_file_name(writer), basename(fifo)))
  expect_equal(
    conn_write(writer, "hello\nthere\n"),
    raw(0)
  )

  expect_equal(
    poll(list(reader), 1000),
    list("ready")
  )

  # Windows might read nothing the first time
  line <- conn_read_lines(reader, 1)
  if (!length(line)) line <- conn_read_lines(reader, 1)
  expect_equal(line, "hello")

  rest <- conn_read_chars(reader)
  expect_equal(rest, "there\n")

  expect_true(conn_is_incomplete(reader))
  expect_true(conn_is_incomplete(writer))

  close(writer)
  expect_equal(
    conn_read_lines(reader),
    character()
  )
  expect_false(conn_is_incomplete(reader))
})

test_that("write end first", {
  skip_on_cran()

  writer <- conn_create_fifo(write = TRUE)
  # this currently fails on Windows if there is no reader attached
  # we'll fix this eventually
  if (is_windows()) {
    expect_error(conn_write(writer, "testing\n"))
  }
  expect_true(conn_is_incomplete(writer))

  reader <- conn_connect_fifo(conn_file_name(writer))
  expect_equal(
    poll(list(reader), 10),
    list("timeout")
  )

  # Now we can write, on Windows as well
  expect_equal(
    conn_write(writer, "hello\nthere\n"),
    raw(0)
  )

  expect_equal(
    poll(list(reader), 1000),
    list("ready")
  )

  # Windows might read nothing the first time
  line <- conn_read_lines(reader, 1)
  if (!length(line)) line <- conn_read_lines(reader, 1)
  expect_equal(line, "hello")

  rest <- conn_read_chars(reader)
  expect_equal(rest, "there\n")

  expect_true(conn_is_incomplete(reader))
  expect_true(conn_is_incomplete(writer))

  close(writer)
  expect_equal(
    conn_read_lines(reader),
    character()
  )
  expect_false(conn_is_incomplete(reader))
})

test_that("write end first 2", {
  skip_on_cran()

  writer <- conn_create_fifo(write = TRUE)
  reader <- conn_connect_fifo(conn_file_name(writer), read = TRUE)
  expect_equal(
    conn_write(writer, "hello\nthere\n"),
    raw(0)
  )

  expect_equal(
    poll(list(reader), 1000),
    list("ready")
  )

  # Windows might read nothing the first time
  line <- conn_read_lines(reader, 1)
  if (!length(line)) line <- conn_read_lines(reader, 1)
  expect_equal(line, "hello")

  rest <- conn_read_chars(reader)
  expect_equal(rest, "there\n")

  expect_true(conn_is_incomplete(reader))
  expect_true(conn_is_incomplete(writer))

  close(writer)
  expect_equal(
    conn_read_lines(reader),
    character()
  )
  expect_false(conn_is_incomplete(reader))
})

test_that("errors", {
  skip_on_cran()

  expect_error(
    conn_create_fifo(read = TRUE, write= TRUE)
  )

  reader <- conn_create_fifo(read = TRUE)
  on.exit(close(reader), add = TRUE)

  expect_error(
    conn_connect_fifo(read = TRUE, write = TRUE)
  )

  if (!is_windows()) {
    expect_error(
      conn_create_fifo(tempdir(), read = TRUE)
    )

    fifo <- tempfile()
    expect_error(
      conn_connect_fifo(fifo)
    )
  }
})
