# is_string

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

---

    Code
      assert_that(is_string(n))
    Condition
      Error:
      ! ! n is not a string (length 1 character)

# is_string_or_null

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

---

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

---

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

---

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

---

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

---

    Code
      assert_that(is_string_or_null(n))
    Condition
      Error:
      ! ! n must be a string (length 1 character) or NULL

# is_flag

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

---

    Code
      assert_that(is_flag(n))
    Condition
      Error:
      ! ! n is not a flag (length 1 logical)

# is_integerish_scalar

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

---

    Code
      assert_that(is_integerish_scalar(n))
    Condition
      Error:
      ! ! n is not a length 1 integer

# is_pid

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

---

    Code
      assert_that(is_pid(n))
    Condition
      Error:
      ! ! n is not a process id (length 1 integer)

# is_flag_or_string

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

---

    Code
      assert_that(is_flag_or_string(n))
    Condition
      Error:
      ! ! n is not a flag or a string

# is_existing_file

    Code
      assert_that(is_existing_file(tempfile()))
    Condition
      Error:
      ! ! File tempfile() does not exist

# failure messages of other assertions

    Code
      assert_that(is_nonneg_numeric_scalar(x))
    Condition
      Error:
      ! ! x is not a non-negative length 1 number
    Code
      assert_that(is_time_interval("foo"))
    Condition
      Error:
      ! ! "foo" is not a valid time interval
    Code
      assert_that(is_list_of_pollables("foo"))
    Condition
      Error:
      ! ! "foo" is not a list of pollable objects
    Code
      assert_that(is_list_of_pollables(list(1)))
    Condition
      Error:
      ! ! list(1) is not a list of pollable objects
    Code
      assert_that(is_named_character(c("a", "b")))
    Condition
      Error:
      ! ! c("a", "b") must be a named character vector
    Code
      assert_that(is_named(list(1, 2)))
    Condition
      Error:
      ! ! list(1, 2) must have non-empty names
    Code
      assert_that(is_connection("foo"))
    Condition
      Error:
      ! ! "foo" must be a processx connection
    Code
      assert_that(is_connection_list(list("foo")))
    Condition
      Error:
      ! ! list("foo") must be a list of processx connections
    Code
      assert_that(is_env_vector(1))
    Condition
      Error:
      ! ! all elements, except "current" must be named in 1
    Code
      assert_that(is_env_vector(c(a = "1", "foo")))
    Condition
      Error:
      ! ! all elements, except "current" must be named in c(a = "1", "foo")
    Code
      assert_that(is_std_conn(1))
    Condition
      Error:
      ! ! 1 must be `NULL`, a string or a processx connection

# assert_that() checks the result of the assertion

    Code
      assert_that("foo")
    Condition
      Error:
      ! ! assert_that: assertion must return a logical value
    Code
      assert_that(NA)
    Condition
      Error:
      ! ! assert_that: missing values present in assertion
    Code
      assert_that(c(TRUE, TRUE))
    Condition
      Error:
      ! ! assert_that: length of assertion is not 1

# assert_that() uses the msg attribute and the default message

    Code
      assert_that(f())
    Condition
      Error:
      ! ! custom message

---

    Code
      assert_that(g(1))
    Condition
      Error:
      ! ! g(1) is not TRUE
    Code
      assert_that(g(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
        20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30))
    Condition
      Error:
      ! ! g(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, ... is not TRUE

# has_attr

    Code
      assert_that(has_attr(x, "baz"))
    Condition
      Error:
      ! ! x does not have attribute baz

