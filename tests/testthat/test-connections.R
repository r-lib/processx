
context("Connections")

test_that("lot of text", {
  if (os_type() != "unix") skip("Only Unix")
  txt <- strrep("x", 10000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new("cat", tmp, stdout = "|")
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})

test_that("UTF-8", {
  if (!l10n_info()$`UTF-8`) skip("Only on UTF-8 platforms")
  if (os_type() != "unix") skip("Only Unix")

  txt <- strrep("\u2192", 10000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new("cat", tmp, stdout = "|")
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})
