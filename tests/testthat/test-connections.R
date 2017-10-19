
context("Connections")

test_that("lot of text", {
  if (os_type() != "unix") skip("Only Unix")
  txt <- strrep("x", 100000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new("cat", tmp, stdout = "|")
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})

test_that("UTF-8", {
  if (!l10n_info()$`UTF-8`) skip("Only on UTF-8 platforms")
  if (os_type() != "unix") skip("Only Unix")

  txt <- strrep(paste0("\u00a0\u2192", "\xf0\x90\x84\x82"), 20000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new("cat", tmp, stdout = "|")
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})

test_that("UTF-8 multibyte character cut in half", {
  if (!l10n_info()$`UTF-8`) skip("Only on UTF-8 platforms")
  if (os_type() != "unix") skip("Only Unix")

  rtxt <- charToRaw("a\u00a0a")

  writeBin(rtxt[1:2], tmp1 <- tempfile())
  writeBin(rtxt[3:4], tmp2 <- tempfile())

  p <- process$new("cat", c(tmp1, tmp2), stdout = "|")
  out <- p$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))

  cmd <- paste("(cat", shQuote(tmp1), ";sleep 1;cat", shQuote(tmp2), ")")
  p <- process$new(commandline = cmd, stdout = "|", stderr = "|")
  out <- p$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))
})

test_that("UTF-8 multibyte character cut in half at the end of the file", {
  if (!l10n_info()$`UTF-8`) skip("Only on UTF-8 platforms")
  if (os_type() != "unix") skip("Only Unix")

  rtxt <- charToRaw("a\u00a0a")
  writeBin(c(rtxt, rtxt[1:2]), tmp1 <- tempfile())

  p <- process$new("cat", tmp1, stdout = "|")
  expect_warning(
    out <- p$read_all_output_lines(),
    "Invalid multi-byte character at end of stream ignored"
  )
  expect_equal(charToRaw(out), c(rtxt, rtxt[1]))
})

test_that("Invalid UTF-8 characters in the middle of the string", {
  if (!l10n_info()$`UTF-8`) skip("Only on UTF-8 platforms")
  if (os_type() != "unix") skip("Only Unix")

  half <- charToRaw("\u00a0")[1]
  rtxt <- sample(rep(c(half, charToRaw("a")), 100))
  writeBin(rtxt, tmp1 <- tempfile())

  p <- process$new("cat", tmp1, stdout = "|")
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(out, strrep("a", 100))
})

test_that("Convert from another encoding to UTF-8", {
  if (os_type() != "unix") skip("Only Unix")

  latin1 <- "\xe1\xe9\xed";
  writeBin(charToRaw(latin1), tmp1 <- tempfile())

  p <- process$new("cat", tmp1, stdout = "|", encoding = "latin1")
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(out, "\xc3\xa1\xc3\xa9\xc3\xad")
})
