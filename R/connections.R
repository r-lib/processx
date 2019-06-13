
#' Processx connections
#'
#' These functions are currently experimental and will change
#' in the future. Note that processx connections are  _not_
#' compatible with R's built-in connection system.
#'
#' `conn_create_fd()` creates a connection from a file descriptor.
#'
#' @param fd Integer scalar, a Unix file descriptor.
#' @param encoding Encoding of the readable connection when reading.
#'   Encoding to re-encode `str` into when writing.
#' @param close Whether to close the OS file descriptor when closing
#'   the connection. Sometimes you want to leave it open, and use it again
#'   in a `conn_create_fd` call.
#'
#' @rdname processx_connections
#' @export

conn_create_fd <- function(fd, encoding = "", close = TRUE) {
  assert_that(
    is_integerish_scalar(fd) || typeof(fd) == "externalptr",
    is_string(encoding),
    is_flag(close))
  if (typeof(df) != "externalptr") fd <- as.integer(fd)
  rethrow_call(c_processx_connection_create_fd, fd, encoding, close)
}

#' @details
#' `conn_create_pipepair()` creates a pair of connected connections, the
#' first one is writeable, the second one is readable.
#'
#' @param nonblocking Whether the writeable and the readable ends of
#'   the pipe should be non-blocking connections.
#'
#' @rdname processx_connections
#' @export

conn_create_pipepair <- function(encoding = "",
                                 nonblocking = c(TRUE, FALSE)) {
  assert_that(
    is_string(encoding),
    is.logical(nonblocking), length(nonblocking) == 2,
    !any(is.na(nonblocking)))
  rethrow_call(c_processx_connection_create_pipepair, encoding, nonblocking)
}

#' @details
#' `conn_read_chars()` reads UTF-8 characters from the connections. If the
#' connection itself is not UTF-8 encoded, it re-encodes it.
#'
#' @param con Processx connection object.
#' @param n Number of characters or lines to read. -1 means all available
#' characters or lines.
#'
#' @rdname processx_connections
#' @export

conn_read_chars <- function(con, n = -1)
  UseMethod("conn_read_chars", con)

#' @rdname processx_connections
#' @export

conn_read_chars.processx_connection <- function(con, n = -1) {
  processx_conn_read_chars(con, n)
}

#' @rdname processx_connections
#' @export

processx_conn_read_chars <- function(con, n = -1) {
  assert_that(is_connection(con), is_integerish_scalar(n))
  rethrow_call(c_processx_connection_read_chars, con, n)
}

#' @details
#' `conn_read_lines()` reads lines from a connection.
#'
#' @rdname processx_connections
#' @export

conn_read_lines <- function(con, n = -1)
  UseMethod("conn_read_lines", con)

#' @rdname processx_connections
#' @export

conn_read_lines.processx_connection <- function(con, n = -1) {
  processx_conn_read_lines(con, n)
}

#' @rdname processx_connections
#' @export

processx_conn_read_lines <- function(con, n = -1) {
  assert_that(is_connection(con), is_integerish_scalar(n))
  rethrow_call(c_processx_connection_read_lines, con, n)
}

#' @details
#' `conn_is_incomplete()` returns `FALSE` if the connection surely has no
#' more data.
#'
#' @rdname processx_connections
#' @export

conn_is_incomplete <- function(con)
  UseMethod("conn_is_incomplete", con)

#' @rdname processx_connections
#' @export

conn_is_incomplete.processx_connection <- function(con) {
  processx_conn_is_incomplete(con)
}

#' @rdname processx_connections
#' @export

processx_conn_is_incomplete <- function(con) {
  assert_that(is_connection(con))
  ! rethrow_call(c_processx_connection_is_eof, con)
}

#' @details
#' `conn_write()` writes a character or raw vector to the connection.
#' It might not be able to write all bytes into the connection, in which
#' case it returns the leftover bytes in a raw vector. Call `conn_write()`
#' again with this raw vector.
#'
#' @param str Character or raw vector to write.
#' @param sep Separator to use if `str` is a character vector. Ignored if
#' `str` is a raw vector.
#'
#' @rdname processx_connections
#' @export

conn_write <- function(con, str, sep = "\n", encoding = "")
  UseMethod("conn_write", con)

#' @rdname processx_connections
#' @export

conn_write.processx_connection <- function(con, str, sep = "\n",
                                           encoding = "") {
  processx_conn_write(con, str, sep, encoding)
}

#' @rdname processx_connections
#' @export

processx_conn_write <- function(con, str, sep = "\n", encoding = "") {
  assert_that(
    is_connection(con),
    (is.character(str) && all(! is.na(str))) || is.raw(str),
    is_string(sep),
    is_string(encoding))

  if (is.character(str)) {
    pstr <- paste(str, collapse = sep)
    str <- iconv(pstr, "", encoding, toRaw = TRUE)[[1]]
  }
  invisible(rethrow_call(c_processx_connection_write_bytes, con, str))
}

#' @details
#' `conn_create_file()` creates a connection to a file.
#'
#' @param filename File name.
#' @param read Whether the connection is readable.
#' @param write Whethe the connection is writeable.
#'
#' @rdname processx_connections
#' @export

conn_create_file <- function(filename, read = NULL, write = NULL) {
  if (is.null(read) && is.null(write)) { read <- TRUE; write <- FALSE }
  if (is.null(read)) read <- !write
  if (is.null(write)) write <- !read

  assert_that(
    is_string(filename),
    is_flag(read),
    is_flag(write),
    read || write)

  rethrow_call(c_processx_connection_create_file, filename, read, write)
}

#' @details
#' `conn_set_stdout()` set the standard output of the R process, to the
#' specified connection.
#'
#' @param drop Whether to close the original stdout/stderr, or keep it
#' open and return a connection to it.
#'
#' @rdname processx_connections
#' @export

conn_set_stdout <- function(con, drop = TRUE) {
  assert_that(
    is_connection(con),
    is_flag(drop))

  flush(stdout())
  invisible(rethrow_call(c_processx_connection_set_stdout, con, drop))
}

#' @details
#' `conn_set_stderr()` set the standard error of the R process, to the
#' specified connection.
#'
#' @rdname processx_connections
#' @export

conn_set_stderr <- function(con, drop = TRUE) {
  assert_that(
    is_connection(con),
    is_flag(drop))

  flush(stderr())
  invisible(rethrow_call(c_processx_connection_set_stderr, con, drop))
}

#' @details
#' `conn_get_fileno()` return the integer file desciptor that belongs to
#' the connection.
#'
#' @rdname processx_connections
#' @export

conn_get_fileno <- function(con) {
  rethrow_call(c_processx_connection_get_fileno, con)
}

#' @details
#' `conn_disable_inheritance()` can be called to disable the inheritance
#' of all open handles. Call this function as soon as possible in a new
#' process to avoid inheriting the inherited handles even further.
#' The function is best effort to close the handles, it might still leave
#' some handles open. It should work for `stdin`, `stdout` and `stderr`,
#' at least.
#'
#' @rdname processx_connections
#' @export

conn_disable_inheritance <- function() {
  rethrow_call(c_processx_connection_disable_inheritance)
}

#' @rdname processx_connections
#' @export

close.processx_connection <- function(con, ...) {
  processx_conn_close(con, ...)
}

#' @param ... Extra arguments, for compatibility with the `close()`
#'    generic, currently ignored by processx.
#' @rdname processx_connections
#' @export

processx_conn_close <- function(con, ...) {
  rethrow_call(c_processx_connection_close, con)
}

conn_create_mmap <- function(data, close = TRUE) {
  assert_that(
    is.list(data),
    is_flag(close))
  map <- .Call(c_processx__mmap_pack, tempfile(), data)
  ret <- .Call(c_processx_connection_create_fd, map[[1]], "", close)
  attr(ret, "size") <- map[[2]]
  ret
}

conn_unpack_mmap <- function(fd) {
  assert_that(
    is_integerish_scalar(fd))
  fd <- as.integer(fd)
  .Call(c_processx__mmap_unpack, fd)
}
