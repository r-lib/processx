# Processx FIFOs

**\[experimental\]**

Create a FIFO for inter-process communication Note that these functions
are currently experimental.

## Usage

``` r
conn_create_fifo(
  filename = NULL,
  read = NULL,
  write = NULL,
  encoding = "",
  nonblocking = TRUE
)

conn_connect_fifo(
  filename,
  read = NULL,
  write = NULL,
  encoding = "",
  nonblocking = TRUE
)
```

## Arguments

- filename:

  File name of the FIFO. On Windows it the name of the pipe within the
  `\\?\pipe\` namespace, either the full name, or the part after that
  prefix. If `NULL`, then a random name is used, on Unix in the R
  temporary directory:
  [`base::tempdir()`](https://rdrr.io/r/base/tempfile.html).

- read:

  If `TRUE` then connect to the read end of the FIFO. Exactly one of
  `read` and `write` must be set to `TRUE`.

- write:

  If `TRUE` then connect to the write end of the FIFO. Exactly one of
  `read` and `write` must be set to `TRUE`.

- encoding:

  Encoding to assume.

- nonblocking:

  Whether this should be a non-blocking FIFO. Note that blocking FIFOs
  are not well tested and might not work well with
  [`poll()`](http://processx.r-lib.org/dev/reference/poll.md),
  especially on Windows. We might remove this option in the future and
  make all FIFOs non-blocking.

## Details

`conn_create_fifo()` creates a FIFO and connects to it. On Unix this is
a proper FIFO in the file system, in the R temporary directory. On
Windows it is a named pipe.

Use
[`conn_file_name()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
to query the name of the FIFO, and `conn_connect_fifo()` to connect to
the other end.

`conn_connect_fifo()` connects to a FIFO created with
`conn_create_fifo()`, typically in another process. `filename` refers to
the name of the pipe on Windows.

On Windows, `conn_connect_fifo()` may be successful even if the FIFO
does not exist, but then later
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md) or
read/write operations will fail. We are planning on changing this
behavior in the future, to make `conn_connect_fifo()` fail immediately,
like on Unix.

## Notes

### In general Unix domain sockets work better than FIFOs, so we suggest

you use sockets if you can. See
[`conn_create_unix_socket()`](http://processx.r-lib.org/dev/reference/processx_sockets.md).

### Creating the read end of the FIFO

This case is simpler. To wait for a writer to connect to the FIFO you
can use [`poll()`](http://processx.r-lib.org/dev/reference/poll.md) as
usual. Then use
[`conn_read_chars()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
or
[`conn_read_lines()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
to read from the FIFO, as usual. Use
[`conn_is_incomplete()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
*after* a read to check if there is more data, or the writer is done.

### Creating the write end of the FIFO

This is somewhat trickier. Creating the (non-blocking) FIFO does not
block. However, there is no easy way to tell if a reader is connected to
the other end of the FIFO or not. On Unix you can start using
[`conn_write()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
to try to write to it, and this will succeed, until the buffer gets
full, even if there is no reader. (When the buffer is full it will
return the data that was not written, as usual.)

On Windows, using
[`conn_write()`](http://processx.r-lib.org/dev/reference/processx_connections.md)
to write to a FIFO without a reader fails with an error. This is not
great, we are planning to improve it later.

Right now, one workaround for this behavior is for the reader to
connunicate to the writer process independenctly that it has connected
to the FIFO. (E.g. another FIFO in the opposite direction can do that.)

## See also

[processx
internals](https://processx.r-lib.org/dev/articles/internals.html)

## Examples

``` r
# Example for a non-blocking FIFO

# Need to open the reading end first, otherwise Unix fails
reader <- conn_create_fifo()

# Always use poll() before you read, with a timeout if you like.
# If you read before the other end of the FIFO is connected, then
# the OS (or processx?) assumes that the FIFO is done, and you cannot
# read anything.
# Now poll() tells us that there is no data yet.
poll(list(reader), 0)
#> [[1]]
#> [1] "timeout"
#> 

writer <- conn_connect_fifo(conn_file_name(reader), write = TRUE)
conn_write(writer, "hello\nthere!\n")

poll(list(reader), 1000)
#> [[1]]
#> [1] "ready"
#> 
conn_read_lines(reader, 1)
#> [1] "hello"
conn_read_chars(reader)
#> [1] "there!\n"

conn_is_incomplete(reader)
#> [1] TRUE

close(writer)
#> NULL
conn_read_chars(reader)
#> [1] ""
conn_is_incomplete(reader)
#> [1] FALSE

close(reader)
#> NULL
```
