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
  expect_identical(full_path("/"), paste0(drive, "/"))
  expect_identical(full_path("a"), file.path(getwd(), "a"))
  expect_identical(full_path("a/b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("a/../b/c"), file.path(getwd(), "b/c"))
  expect_identical(full_path("../../../../../../../../../../../a"), file.path(drive, "a"))
  expect_identical(full_path("/../.././a"), file.path(drive, "a"))
  expect_identical(full_path("/a/./b/../c"), file.path(drive, "a/c"))
  expect_identical(full_path("~nonexistent_user"), file.path(getwd(), "~nonexistent_user"))
  expect_identical(full_path("~/a/../b"), path.expand("~/b"))
})

test_that("full_path gives correct values, windows", {
  skip_other_platforms("windows")

  expect_identical(full_path("f:/a/b"), "f:/a/b")
  expect_identical(full_path("f:/a/b/../../.."), "f:/")
  expect_identical(full_path("f:/../a"), "f:/a")
  expect_identical(full_path("f:/"), "f:/")
})
