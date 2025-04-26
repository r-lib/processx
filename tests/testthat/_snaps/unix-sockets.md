# CRUD

    Code
      conn_accept_unix_socket(sock1)
    Condition
      Error:
      ! Native call to `processx_connection_accept_socket` failed
      Caused by error:
      ! Socket is not listening @processx-connection.c:540 (processx_connection_accept_socket)

# reading unaccepted server socket is error

    Code
      conn_read_chars(sock1)
    Condition
      Error:
      ! Native call to `processx_connection_read_chars` failed
      Caused by error:
      ! Cannot read from processx connection (system error 57, Socket is not connected) @processx-connection.c:1828 (processx__connection_read)

# writing unaccepted server socket is error

    Code
      conn_write(sock1, "Hello\n")
    Condition
      Error:
      ! Native call to `processx_connection_write_bytes` failed
      Caused by error:
      ! Cannot write to an un-accepted socket connection @processx-connection.c:966 (processx_c_connection_write_bytes)

# errors

    Code
      conn_create_unix_socket(sock)
    Condition
      Error:
      ! Native call to `processx_connection_create_socket` failed
      Caused by error:
      ! Server socket path too long: <tempdir>/<tempfile>
    Code
      conn_create_unix_socket("/dev/null")
    Condition
      Error:
      ! Native call to `processx_connection_create_socket` failed
      Caused by error:
      ! Cannot bind to socket (system error 48, Address already in use) @processx-connection.c:442 (processx_connection_create_socket)
    Code
      conn_connect_unix_socket("/dev/null")
    Condition
      Error:
      ! Native call to `processx_connection_connect_socket` failed
      Caused by error:
      ! Cannot connect to socket (system error 38, Socket operation on non-socket) @processx-connection.c:513 (processx_connection_connect_socket)

---

    Code
      conn_accept_unix_socket(ff)
    Condition
      Error:
      ! Native call to `processx_connection_accept_socket` failed
      Caused by error:
      ! Not a socket connection @processx-connection.c:536 (processx_connection_accept_socket)

---

    Code
      conn_unix_socket_state(ff)
    Condition
      Error:
      ! Native call to `processx_connection_socket_state` failed
      Caused by error:
      ! Not a socket connection @processx-connection.c:585 (processx_connection_socket_state)

