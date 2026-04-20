# reading unaccepted server socket is error

    Code
      conn_read_chars(sock1)
    Condition
      Error in `processx_conn_read_chars()`:
      ! ! Native call to `processx_connection_read_chars` failed
      Caused by error in `chain_call(c_processx_connection_read_chars, con, n)` at connections.R:302:<col>:
      ! Cannot read from processx connection (system error 22, Invalid argument) @processx-connection.c:1891 (processx__connection_read)

# errors

    Code
      conn_create_unix_socket(sock)
    Condition
      Error in `conn_create_unix_socket()`:
      ! ! Native call to `processx_connection_create_socket` failed
      Caused by error in `chain_call(c_processx_connection_create_socket, filename, encoding)` at connections.R:618:<col>:
      ! Server socket path too long: <tempdir>/<tempfile>
    Code
      conn_create_unix_socket("/dev/null")
    Condition
      Error in `conn_create_unix_socket()`:
      ! ! Native call to `processx_connection_create_socket` failed
      Caused by error in `chain_call(c_processx_connection_create_socket, filename, encoding)` at connections.R:618:<col>:
      ! Cannot bind to socket (system error 98, Address already in use) @processx-connection.c:479 (processx_connection_create_socket)
    Code
      conn_connect_unix_socket("/dev/null")
    Condition
      Error in `conn_connect_unix_socket()`:
      ! ! Native call to `processx_connection_connect_socket` failed
      Caused by error in `chain_call(c_processx_connection_connect_socket, filename, encoding)` at connections.R:640:<col>:
      ! Cannot connect to socket (system error 111, Connection refused) @processx-connection.c:550 (processx_connection_connect_socket)

