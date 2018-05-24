
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
#' Encoding to re-encode `str` into when writing.
#'
#' @rdname processx_connections
#' @export

conn_create_fd <- function(fd, encoding = "") {
  assert_that(
    is_integerish_scalar(fd),
    is_string(encoding))
  fd <- as.integer(fd)
  .Call(c_processx_connection_create_fd, fd, encoding)
}

#' `conn_create_pipepair()` creates a pair of connected connections, the
#' first one is writeable, the second one is readable.
#'
#' @rdname processx_connections
#' @export

conn_create_pipepair <- function(encoding = "") {
  assert_that(is_string(encoding))
  .Call(c_processx_connection_create_pipepair, encoding)
}

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
  UseMethod("conn_read_chars")

#' @rdname processx_connections
#' @export

conn_read_chars.processx_connection <- function(con, n = -1) {
  assert_that(is_connection(con), is_integerish_scalar(n))
  .Call(c_processx_connection_read_chars, con, n)
}

#' `conn_read_lines()` reads lines from a connection.
#'
#' @rdname processx_connections
#' @export

conn_read_lines <- function(con, n = -1)
  UseMethod("conn_read_lines")

#' @rdname processx_connections
#' @export

conn_read_lines.processx_connection <- function(con, n = -1) {
  assert_that(is_connection(con), is_integerish_scalar(n))
  .Call(c_processx_connection_read_lines, con, n)
}

#' `conn_is_incomplete()` returns `FALSE` if the connection surely has no
#' more data.
#'
#' @rdname processx_connections
#' @export

conn_is_incomplete <- function(con)
  UseMethod("conn_is_incomplete")

#' @rdname processx_connections
#' @export

conn_is_incomplete.processx_connection <- function(con) {
  assert_that(is_connection(con))
  ! .Call(c_processx_connection_is_eof, con)
}

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
  UseMethod("conn_write")

#' @rdname processx_connections
#' @export

conn_write.processx_connection <- function(con, str, sep = "\n",
                                           encoding = "") {
  assert_that(
    is_connection(con),
    (is.character(str) && all(! is.na(str))) || is.raw(str),
    is_string(sep),
    is_string(encoding))

  if (is.character(str)) {
    pstr <- paste(str, collapse = sep)
    str <- iconv(pstr, "", encoding, toRaw = TRUE)[[1]]
  }
  invisible(.Call(c_processx_connection_write_bytes, con, str))
}