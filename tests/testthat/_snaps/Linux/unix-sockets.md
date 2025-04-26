# reading unaccepted server socket is error

    Code
      conn_read_chars(sock1)
    Condition
      Error:
      ! Native call to `processx_connection_read_chars` failed
      Caused by error:
      ! Cannot read from processx connection (system error 22, Invalid argument) @processx-connection.c:1828 (processx__connection_read)

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
      ! Cannot bind to socket (system error 98, Address already in use) @processx-connection.c:442 (processx_connection_create_socket)
    Code
      conn_connect_unix_socket("/dev/null")
    Condition
      Error:
      ! Native call to `processx_connection_connect_socket` failed
      Caused by error:
      ! Cannot connect to socket (system error 111, Connection refused) @processx-connection.c:513 (processx_connection_connect_socket)

