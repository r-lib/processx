# full_path gives correct values, windows

    Code
      full_path("//")
    Condition
      Error in `full_path()`:
      ! ! Server name not found in network path.
    Code
      full_path("///")
    Condition
      Error in `full_path()`:
      ! ! Server name not found in network path.
    Code
      full_path("///a")
    Condition
      Error in `full_path()`:
      ! ! Server name not found in network path.

