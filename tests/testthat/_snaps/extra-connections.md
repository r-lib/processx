# conn_create_fd()

    Code
      conn_create_fd("foo")
    Condition
      Error:
      ! ! fd is not a length 1 integer
    Code
      conn_create_fd(0L, encoding = 1)
    Condition
      Error:
      ! ! encoding is not a string (length 1 character)
    Code
      conn_create_fd(0L, close = NA)
    Condition
      Error:
      ! ! close is not a flag (length 1 logical)

# conn_read_bytes()

    Code
      processx_conn_read_bytes("foo")
    Condition
      Error:
      ! ! con must be a processx connection
    Code
      processx_conn_read_bytes(con, "x")
    Condition
      Error:
      ! ! n is not a length 1 integer

# is_valid_fd()

    Code
      is_valid_fd("foo")
    Condition
      Error:
      ! ! fd is not a length 1 integer

