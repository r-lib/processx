
context("handles")

test_that("handle roundtrip, unix", {
  skip_other_platforms("unix")

  h <- handle_create(1)
  expect_s3_class(h, "processx_handle")
  expect_identical(typeof(h), "externalptr")

  d <- handle_describe(h)
  expect_identical(d, "1")
})
