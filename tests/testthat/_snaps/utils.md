# full_path gives correct values, windows

    Code
      full_path("//")
    Condition
      Error:
      ! Server name not found in network path.
    Code
      full_path("///")
    Condition
      Error:
      ! Server name not found in network path.
    Code
      full_path("///a")
    Condition
      Error:
      ! Server name not found in network path.

