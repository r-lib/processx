# reading unaccepted server socket is error

    Code
      conn_read_chars(sock1)
    Condition
      Error:
      ! ! Native call to `processx_connection_read_chars` failed
      Caused by error in `chain_call(c_processx_connection_read_chars, con, n)` at connections.R:302:<col>:
      ! Cannot read from an un-accepted socket connection @processx-connection.c:1731 (processx__connection_read)

