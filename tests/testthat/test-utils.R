context("utils")

test_that("full_path gives correct values", {
  if (is_windows()) {
    # Will be something like "C:"
    drive <- substring(getwd(), 1, 2)
  } else {
    # Use "" so that file.path("", "a") will return "/a"
    drive <- ""
  }

  expect_identical(full_path("/a/b"), file.path(drive, "a/b"))
  expect_identical(full_path("/a/b/"), file.path(drive, "a/b"))
  expect_identical(full_path("/"), file.path(drive, ""))
  expect_identical(full_path("a"), file.path(getwd(), "a"))
  expect_identical(full_path("a/b"), file.path(getwd(), "a/b"))

  expect_identical(full_path("a/../b/c"), file.path(getwd(), "b/c"))
  expect_identical(full_path("../../../../../../../../../../../a"), file.path(drive, "a"))
  expect_identical(full_path("/../.././a"), file.path(drive, "a"))
  expect_identical(full_path("/a/./b/../c"), file.path(drive, "a/c"))

  expect_identical(full_path("~nonexistent_user"), file.path(getwd(), "~nonexistent_user"))
  expect_identical(full_path("~/a/../b"), path.expand("~/b"))

  expect_identical(full_path("a//b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("/a//b"), file.path(drive, "a/b"))
})

test_that("full_path gives correct values, windows", {
  skip_other_platforms("windows")

  # Backslash separators
  expect_identical(full_path("f:\\a/b"), "f:/a/b")
  expect_identical(full_path("a\\b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("a\\\\b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("\\\\a\\b"), "//a/b")
  expect_identical(full_path("\\\\a/b/..\\c"), "//a/c")

  # Drives
  expect_identical(full_path("f:/a/b"), "f:/a/b")
  expect_identical(full_path("f:/a/b/../../.."), "f:/")
  expect_identical(full_path("f:/../a"), "f:/a")
  expect_identical(full_path("f:/"), "f:/")
  expect_identical(full_path("f:"), "f:/")

  # Leading double slashes. Server name always has trailing slash ("//server/"),
  # like drives do ("f:/"). But dirs on the server don't have a trailing slash.
  expect_identical(full_path("//a"), "//a/")
  expect_identical(full_path("//a/"), "//a/")
  expect_identical(full_path("//a/b"), "//a/b")
  expect_identical(full_path("//a/b/.."), "//a/")
  # Can't go .. to remove the server name
  expect_identical(full_path("//a/b/../.."), "//a/")
  expect_identical(full_path("//a/../b"), "//a/b")
  expect_error(full_path("//"))
  expect_error(full_path("///"))
  expect_error(full_path("///a"))
})

test_that("full_path gives correct values, unix", {
  skip_other_platforms("unix")

  # Leading double slashes should collapse
  expect_identical(full_path("//"), "/")
  expect_identical(full_path("///a/"), "/a")
})
