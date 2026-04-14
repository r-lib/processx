# CRUD

    Code
      conn_accept_unix_socket(sock1)
    Condition
      Error:
      ! ! Native call to `processx_connection_accept_socket` failed
      Caused by error in `chain_call(c_processx_connection_accept_socket, con)` at connections.R:653:<col>:
      ! Socket is not listening @processx-connection.c:577 (processx_connection_accept_socket)

# writing unaccepted server socket is error

    Code
      conn_write(sock1, "Hello\n")
    Condition
      Error:
      ! ! Native call to `processx_connection_write_bytes` failed
      Caused by error in `chain_call(c_processx_connection_write_bytes, con, str)` at connections.R:424:<col>:
      ! Cannot write to an un-accepted socket connection @processx-connection.c:1009 (processx_c_connection_write_bytes)

# errors

    Code
      conn_accept_unix_socket(ff)
    Condition
      Error:
      ! ! Native call to `processx_connection_accept_socket` failed
      Caused by error in `chain_call(c_processx_connection_accept_socket, con)` at connections.R:653:<col>:
      ! Not a socket connection @processx-connection.c:573 (processx_connection_accept_socket)

---

    Code
      conn_unix_socket_state(ff)
    Condition
      Error:
      ! ! Native call to `processx_connection_socket_state` failed
      Caused by error in `chain_call(c_processx_connection_socket_state, con)` at connections.R:665:<col>:
      ! Not a socket connection @processx-connection.c:622 (processx_connection_socket_state)

