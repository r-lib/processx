# can pass frame as error call

    Code
      (expect_error(f()))
    Output
      <rlib_error_3_0/rlib_error/error>
      Error in `f()`:
      ! my message
    Code
      (expect_error(g()))
    Output
      <rlib_error_3_0/rlib_error/error>
      Error in `g()`:
      ! my message

