# Processx connections

These functions are currently experimental and will change in the
future. Note that processx connections are *not* compatible with R's
built-in connection system.

## Usage

``` r
conn_create_fd(fd, encoding = "", close = TRUE)

conn_file_name(con)

conn_create_pipepair(encoding = "", nonblocking = c(TRUE, FALSE))

conn_create_proc_pipepair(encoding = "")

conn_read_chars(con, n = -1)

# S3 method for class 'processx_connection'
conn_read_chars(con, n = -1)

processx_conn_read_chars(con, n = -1)

conn_read_bytes(con, n = -1)

# S3 method for class 'processx_connection'
conn_read_bytes(con, n = -1)

processx_conn_read_bytes(con, n = -1)

conn_read_lines(con, n = -1)

# S3 method for class 'processx_connection'
conn_read_lines(con, n = -1)

processx_conn_read_lines(con, n = -1)

conn_is_incomplete(con)

# S3 method for class 'processx_connection'
conn_is_incomplete(con)

processx_conn_is_incomplete(con)

conn_write(con, str, sep = "\n", encoding = "")

# S3 method for class 'processx_connection'
conn_write(con, str, sep = "\n", encoding = "")

processx_conn_write(con, str, sep = "\n", encoding = "")

conn_create_file(filename, read = NULL, write = NULL)

conn_set_stdout(con, drop = TRUE)

conn_set_stderr(con, drop = TRUE)

conn_get_fileno(con)

conn_disable_inheritance()

# S3 method for class 'processx_connection'
close(con, ...)

processx_conn_close(con, ...)

is_valid_fd(fd)
```

## Arguments

- fd:

  Integer scalar, a Unix file descriptor.

- encoding:

  Encoding of the readable connection when reading.

- close:

  Whether to close the OS file descriptor when closing the connection.
  Sometimes you want to leave it open, and use it again in a
  `conn_create_fd` call. Encoding to re-encode `str` into when writing.

- con:

  Processx connection object.

- nonblocking:

  Whether the pipe should be non-blocking. For `conn_create_pipepair()`
  it must be a logical vector of length two, for both ends of the pipe.

- n:

  Number of characters or lines to read. -1 means all available
  characters or lines.

- str:

  Character or raw vector to write.

- sep:

  Separator to use if `str` is a character vector. Ignored if `str` is a
  raw vector.

- filename:

  File name. For
  [`conn_create_fifo()`](http://processx.r-lib.org/dev/reference/processx_fifos.md)
  on Windows, a `\\?\pipe` prefix is added to this, if it does not have
  such a prefix. For
  [`conn_create_fifo()`](http://processx.r-lib.org/dev/reference/processx_fifos.md)
  it can also be `NULL`, in which case a random file name is used via
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html).

- read:

  Whether the connection is readable.

- write:

  Whethe the connection is writeable.

- drop:

  Whether to close the original stdout/stderr, or keep it open and
  return a connection to it.

- ...:

  Extra arguments, for compatibility with the
  [`close()`](https://rdrr.io/r/base/connections.html) generic,
  currently ignored by processx.

## Details

`conn_create_fd()` creates a connection from a file descriptor.

`conn_file_name()` returns the name of the file associated with the
connection. For connections that do not refer to a file in the file
system it returns `NA_character()`. Except for named pipes on Windows,
where it returns the full name of the pipe.

`conn_create_pipepair()` creates a pair of connected connections, the
first one is writeable, the second one is readable.

`conn_create_proc_pipepair()` creates a unidirectional pipe suitable for
connecting two child processes: the first element is the write end (pass
as `stdout` to the writing process) and the second is the read end (pass
as `stdin` to the reading process). Unlike `conn_create_pipepair()`,
both ends are synchronous (blocking), which is required for
child-process stdin/stdout on Windows.

`conn_read_chars()` reads UTF-8 characters from the connections. If the
connection itself is not UTF-8 encoded, it re-encodes it.

`conn_read_bytes()` reads raw bytes from the connection into a raw
vector. Unlike `conn_read_chars()`, it bypasses UTF-8 conversion, so
null bytes and arbitrary binary data are preserved exactly. Calling this
function switches the connection permanently to raw mode; after that,
`conn_read_chars()` and `conn_read_lines()` must not be used on the same
connection.

`conn_read_lines()` reads lines from a connection.

`conn_is_incomplete()` returns `FALSE` if the connection surely has no
more data.

`conn_write()` writes a character or raw vector to the connection. It
might not be able to write all bytes into the connection, in which case
it returns the leftover bytes in a raw vector. Call `conn_write()` again
with this raw vector.

`conn_create_file()` creates a connection to a file.

`conn_set_stdout()` set the standard output of the R process, to the
specified connection.

`conn_set_stderr()` set the standard error of the R process, to the
specified connection.

`conn_get_fileno()` return the integer file desciptor that belongs to
the connection.

`conn_disable_inheritance()` can be called to disable the inheritance of
all open handles. Call this function as soon as possible in a new
process to avoid inheriting the inherited handles even further. The
function is best effort to close the handles, it might still leave some
handles open. It should work for `stdin`, `stdout` and `stderr`, at
least.

`is_valid_fd()` returns `TRUE` if `fd` is a valid open file descriptor.
You can use it to check if the R process has standard input, output or
error. E.g. R processes running in GUI (like RGui) might not have any of
the standard streams available.

If a stream is redirected to the null device (e.g. in a callr
subprocess), that is is still a valid file descriptor.

## Examples

``` r
is_valid_fd(0L)      # stdin
#> [1] TRUE
is_valid_fd(1L)      # stdout
#> [1] TRUE
is_valid_fd(2L)      # stderr
#> [1] TRUE
```
