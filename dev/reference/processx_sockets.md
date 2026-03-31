# Unix domain sockets

**\[experimental\]**

Cross platform point-to-point inter-process communication with
Unix=domain sockets, implemented via named pipes on Windows. These
connection are always bidirectional, i.e. you can read from them and
also write to them.

## Usage

``` r
conn_create_unix_socket(filename = NULL, encoding = "")

conn_connect_unix_socket(filename, encoding = "")

conn_accept_unix_socket(con)

conn_unix_socket_state(con)
```

## Arguments

- filename:

  File name of the socket. On Windows it the name of the pipe within the
  `\\?\pipe\` namespace, either the full name, or the part after that
  prefix. If `NULL`, then a random name is used, on Unix in the R
  temporary directory:
  [`base::tempdir()`](https://rdrr.io/r/base/tempfile.html).

- encoding:

  Encoding to assume when reading from the socket.

- con:

  Connection. An error is thrown if not a socket connection.

## Value

A new socket connection.

## Details

`conn_create_unix_socket()` creates a server socket. The new socket is
listening at `filename`. See `filename` above.

`conn_connect_unix_socket()` creates a client socket and connects it to
a server socket.

`conn_accept_unix_socket()` accepts a client connection at a server
socket.

`conn_unix_socket_state()` returns the state of the socket. Currently it
can return: `"listening"`, `"connected_server"`, `"connected_client"`.
It is possible that other states (e.g. for a closed socket) will be
added in the future.

### Notes

- [`poll()`](http://processx.r-lib.org/dev/reference/poll.md) works on
  sockets, but only polls for data to read, and currently ignores the
  write-end of the socket.

- [`poll()`](http://processx.r-lib.org/dev/reference/poll.md) also works
  for accepting client connections. It will return `"connect"`is a
  client connection is available for a server socket. After this you can
  call `conn_accept_unix_socket()` to accept the client connection.

## See also

[processx
internals](https://processx.r-lib.org/dev/articles/internals.html)
