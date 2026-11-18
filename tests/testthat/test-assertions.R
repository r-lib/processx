strings <- list("foo", "", "111", "1", "-", "NA")
not_strings <- list(
  1,
  character(),
  NA_character_,
  NA,
  c("foo", NA),
  c("1", "2"),
  NULL
)

test_that("is_string", {
  for (p in strings) {
    expect_true(is_string(p))
    expect_silent(assert_that(is_string(p)))
  }

  for (n in not_strings) {
    expect_false(is_string(n))
    expect_snapshot(error = TRUE, assert_that(is_string(n)))
  }
})

test_that("is_string_or_null", {
  for (p in strings) {
    expect_true(is_string_or_null(p))
    expect_silent(assert_that(is_string_or_null(p)))
  }
  expect_true(is_string_or_null(NULL))
  expect_silent(assert_that(is_string_or_null(NULL)))

  for (n in not_strings) {
    if (!is.null(n)) {
      expect_false(is_string_or_null(n))
      expect_snapshot(error = TRUE, assert_that(is_string_or_null(n)))
    }
  }
})

flags <- list(TRUE, FALSE)
not_flags <- list(
  1,
  character(),
  NA_character_,
  NA,
  c("foo", NA),
  c("1", "2"),
  NULL
)

test_that("is_flag", {
  for (p in flags) {
    expect_true(is_flag(p))
    expect_silent(assert_that(is_flag(p)))
  }

  for (n in not_flags) {
    expect_false(is_flag(n))
    expect_snapshot(error = TRUE, assert_that(is_flag(n)))
  }
})

ints <- list(1, 0, -1, 1L, 0L, -1L, 1.0, 42.0)
not_ints <- list(
  1.2,
  0.1,
  "foo",
  numeric(),
  integer(),
  NULL,
  NA_integer_,
  NA_real_
)

test_that("is_integerish_scalar", {
  for (p in ints) {
    expect_true(is_integerish_scalar(p))
    expect_silent(assert_that(is_integerish_scalar(p)))
  }

  for (n in not_ints) {
    expect_false(is_integerish_scalar(n))
    expect_snapshot(error = TRUE, assert_that(is_integerish_scalar(n)))
  }
})

test_that("is_pid", {
  for (p in ints) {
    expect_true(is_pid(p))
    expect_silent(assert_that(is_pid(p)))
  }

  for (n in not_ints) {
    expect_false(is_pid(n))
    expect_snapshot(error = TRUE, assert_that(is_pid(n)))
  }
})

test_that("is_flag_or_string", {
  for (p in c(flags, strings)) {
    expect_true(is_flag_or_string(p))
    expect_silent(assert_that(is_flag_or_string(p)))
  }

  for (n in intersect(not_flags, not_strings)) {
    expect_false(is_flag_or_string(n))
    expect_snapshot(error = TRUE, assert_that(is_flag_or_string(n)))
  }
})

test_that("is_existing_file", {
  expect_false(is_existing_file(tempfile()))
  expect_snapshot(error = TRUE, assert_that(is_existing_file(tempfile())))

  cat("foo\n", file = tmp <- tempfile())
  on.exit(unlink(tmp), add = TRUE)
  expect_true(is_existing_file(tmp))
  expect_silent(assert_that(is_existing_file(tmp)))
})

test_that("failure messages of other assertions", {
  x <- -1
  expect_snapshot(error = TRUE, {
    assert_that(is_nonneg_numeric_scalar(x))
    assert_that(is_time_interval("foo"))
    assert_that(is_list_of_pollables("foo"))
    assert_that(is_list_of_pollables(list(1)))
    assert_that(is_named_character(c("a", "b")))
    assert_that(is_named(list(1, 2)))
    assert_that(is_connection("foo"))
    assert_that(is_connection_list(list("foo")))
    assert_that(is_env_vector(1))
    assert_that(is_env_vector(c(a = "1", "foo")))
    assert_that(is_std_conn(1))
  })
})

test_that("assert_that() checks the result of the assertion", {
  expect_snapshot(error = TRUE, {
    assert_that("foo")
    assert_that(NA)
    assert_that(c(TRUE, TRUE))
  })
})

test_that("assert_that() uses the msg attribute and the default message", {
  f <- function() structure(FALSE, msg = "custom message")
  expect_snapshot(error = TRUE, assert_that(f()))

  g <- function(...) FALSE
  expect_snapshot(error = TRUE, {
    assert_that(g(1))
    assert_that(g(
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
      21, 22, 23, 24, 25, 26, 27, 28, 29, 30
    ))
  })
})

test_that("has_attr", {
  x <- structure(1, foo = "bar")
  expect_true(has_attr(x, "foo"))
  expect_true(x %has_attr% "foo")
  expect_snapshot(error = TRUE, assert_that(has_attr(x, "baz")))
})
