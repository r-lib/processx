# Package index

## Foreground processes

- [`run()`](http://processx.r-lib.org/reference/run.md) : Run external
  command, and wait until finishes
- [`default_pty_options()`](http://processx.r-lib.org/reference/default_pty_options.md)
  : Default options for pseudo terminals (ptys)

## Background processes

- [`process`](http://processx.r-lib.org/reference/process.md) : External
  process

## Pipelines

- [`pipeline`](http://processx.r-lib.org/reference/pipeline.md)
  **\[experimental\]** : Pipeline of processes connected with pipes

## Polling

- [`poll()`](http://processx.r-lib.org/reference/poll.md) : Poll for
  process I/O or termination
- [`curl_fds()`](http://processx.r-lib.org/reference/curl_fds.md) :
  Create a pollable object from a curl multi handle's file descriptors

## Connections

- [`conn_create_fd()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_file_name()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_create_pipepair()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_create_proc_pipepair()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_read_chars()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_read_chars()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_read_bytes()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_read_bytes()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_read_lines()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_read_lines()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_is_incomplete()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_is_incomplete()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_write()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_write()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_create_file()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_set_stdout()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_set_stderr()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_get_fileno()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`conn_disable_inheritance()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`close(`*`<processx_connection>`*`)`](http://processx.r-lib.org/reference/processx_connections.md)
  [`processx_conn_close()`](http://processx.r-lib.org/reference/processx_connections.md)
  [`is_valid_fd()`](http://processx.r-lib.org/reference/processx_connections.md)
  : Processx connections
- [`conn_create_fifo()`](http://processx.r-lib.org/reference/processx_fifos.md)
  [`conn_connect_fifo()`](http://processx.r-lib.org/reference/processx_fifos.md)
  **\[experimental\]** : Processx FIFOs
- [`conn_create_unix_socket()`](http://processx.r-lib.org/reference/processx_sockets.md)
  [`conn_connect_unix_socket()`](http://processx.r-lib.org/reference/processx_sockets.md)
  [`conn_accept_unix_socket()`](http://processx.r-lib.org/reference/processx_sockets.md)
  [`conn_unix_socket_state()`](http://processx.r-lib.org/reference/processx_sockets.md)
  **\[experimental\]** : Unix domain sockets

## Utility functions

- [`base64_decode()`](http://processx.r-lib.org/reference/base64_decode.md)
  [`base64_encode()`](http://processx.r-lib.org/reference/base64_decode.md)
  : Base64 Encoding and Decoding
