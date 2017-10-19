
context("Connections")

test_that("lot of text", {
  skip_if_no_cat()
  txt <- strrep("x", 100000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new(cat_command(), tmp, stdout = "|")
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})

test_that("UTF-8", {
  skip_if_no_cat()

  txt <- charToRaw(strrep("\xc2\xa0\xe2\x86\x92\xf0\x90\x84\x82", 20000))
  writeBin(txt, con = tmp <- tempfile())

  p <- process$new(cat_command(), tmp, stdout = "|", encoding = "UTF-8")
  out <- p$read_all_output_lines()

  expect_equal(txt, charToRaw(out))
})

test_that("UTF-8 multibyte character cut in half", {
  skip_if_no_cat()

  rtxt <- charToRaw("a\xc2\xa0a")

  writeBin(rtxt[1:2], tmp1 <- tempfile())
  writeBin(rtxt[3:4], tmp2 <- tempfile())

  p <- process$new(cat_command(), c(tmp1, tmp2), stdout = "|", encoding = "UTF-8")
  out <- p$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))

  skip_other_platforms("unix")

  cmd <- paste("(cat", shQuote(tmp1), ";sleep 1;cat", shQuote(tmp2), ")")
  p <- process$new(commandline = cmd, stdout = "|", stderr = "|")
  out <- p$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))
})

test_that("UTF-8 multibyte character cut in half at the end of the file", {
  skip_if_no_cat()

  rtxt <- charToRaw("a\xc2\xa0a")
  writeBin(c(rtxt, rtxt[1:2]), tmp1 <- tempfile())

  p <- process$new(cat_command(), tmp1, stdout = "|", encoding = "UTF-8")
  expect_warning(
    out <- p$read_all_output_lines(),
    "Invalid multi-byte character at end of stream ignored"
  )
  expect_equal(charToRaw(out), c(rtxt, rtxt[1]))
})

test_that("Invalid UTF-8 characters in the middle of the string", {
  skip_if_no_cat()

  half <- charToRaw("\xc2\xa0")[1]
  rtxt <- sample(rep(c(half, charToRaw("a")), 100))
  writeBin(rtxt, tmp1 <- tempfile())

  p <- process$new(cat_command(), tmp1, stdout = "|", encoding = "UTF-8")
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(out, strrep("a", 100))
})

test_that("Convert from another encoding to UTF-8", {
  skip_if_no_cat()

  latin1 <- "\xe1\xe9\xed";
  writeBin(charToRaw(latin1), tmp1 <- tempfile())

  p <- process$new(cat_command(), tmp1, stdout = "|", encoding = "latin1")
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(charToRaw(out), charToRaw("\xc3\xa1\xc3\xa9\xc3\xad"))
})
