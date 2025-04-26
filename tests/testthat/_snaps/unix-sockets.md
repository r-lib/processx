# CRUD

    Code
      conn_accept_unix_socket(sock1)
    Condition
      Error:
      ! Native call to `processx_connection_accept_socket` failed
      Caused by error:
      ! Socket is not listening @processx-connection.c:540 (processx_connection_accept_socket)

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

