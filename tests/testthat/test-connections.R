
if (!is.null(packageDescription("stats")[["ExperimentalWindowsRuntime"]])) {
  if (!identical(Sys.getenv("NOT_CRAN"), "true")) return()
}

test_that("lot of text", {

  px <- get_tool("px")
  txt <- strrep("x", 100000)
  cat(txt, file = tmp <- tempfile())

  p <- process$new(px, c("cat", tmp), stdout = "|")
  on.exit(p$kill(), add = TRUE)
  out <- p$read_all_output_lines()

  expect_equal(txt, out)
})

test_that("UTF-8", {

  px <- get_tool("px")
  txt <- charToRaw(strrep("\xc2\xa0\xe2\x86\x92\xf0\x90\x84\x82", 20000))
  writeBin(txt, con = tmp <- tempfile())

  p <- process$new(px, c("cat", tmp), stdout = "|", encoding = "UTF-8")
  on.exit(p$kill(), add = TRUE)
  out <- p$read_all_output_lines()

  expect_equal(txt, charToRaw(out))
})

test_that("UTF-8 multibyte character cut in half", {

  px <- get_tool("px")

  rtxt <- charToRaw("a\xc2\xa0a")

  writeBin(rtxt[1:2], tmp1 <- tempfile())
  writeBin(rtxt[3:4], tmp2 <- tempfile())

  p1 <- process$new(px, c("cat", tmp1, "cat", tmp2), stdout = "|",
                    encoding = "UTF-8")
  on.exit(p1$kill(), add = TRUE)
  out <- p1$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))

  cmd <- paste("(cat", shQuote(tmp1), ";sleep 1;cat", shQuote(tmp2), ")")
  p2 <- process$new(px, c("cat", tmp1, "sleep", "1", "cat", tmp2),
                    stdout = "|", stderr = "|", encoding = "UTF-8")
  on.exit(p2$kill(), add = TRUE)
  out <- p2$read_all_output_lines()
  expect_equal(rtxt, charToRaw(out))
})

test_that("UTF-8 multibyte character cut in half at the end of the file", {

  px <- get_tool("px")
  rtxt <- charToRaw("a\xc2\xa0a")
  writeBin(c(rtxt, rtxt[1:2]), tmp1 <- tempfile())

  p <- process$new(px, c("cat", tmp1), stdout = "|", encoding = "UTF-8")
  on.exit(p$kill(), add = TRUE)
  expect_warning(
    out <- p$read_all_output_lines(),
    "Invalid multi-byte character at end of stream ignored"
  )
  expect_equal(charToRaw(out), c(rtxt, rtxt[1]))
})

test_that("Invalid UTF-8 characters in the middle of the string", {

  px <- get_tool("px")
  half <- charToRaw("\xc2\xa0")[1]
  rtxt <- sample(rep(c(half, charToRaw("a")), 100))
  writeBin(rtxt, tmp1 <- tempfile())

  p <- process$new(px, c("cat", tmp1), stdout = "|", encoding = "UTF-8")
  on.exit(p$kill(), add = TRUE)
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(out, strrep("a", 100))
})

test_that("Convert from another encoding to UTF-8", {

  px <- get_tool("px")

  latin1 <- "\xe1\xe9\xed";
  writeBin(charToRaw(latin1), tmp1 <- tempfile())

  p <- process$new(px, c("cat", tmp1), stdout = "|", encoding = "latin1")
  on.exit(p$kill(), add = TRUE)
  suppressWarnings(out <- p$read_all_output_lines())

  expect_equal(charToRaw(out), charToRaw("\xc3\xa1\xc3\xa9\xc3\xad"))
})

test_that("Passing connection to stdout", {

  # file first
  tmp <- tempfile()
  con <- conn_create_file(tmp, write = TRUE)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  cmd <- c(get_tool("px"), c("outln", "hello", "outln", "world"))

  p <- process$new(cmd[1], cmd[-1], stdout = con)
  on.exit(p$kill(), add = TRUE)

  p$wait(3000)
  expect_false(p$is_alive())
  # Need to close here, otherwise Windows cannot read it
  close(con)

  out <- readLines(tmp)
  expect_equal(out, c("hello", "world"))

  # pass a pipe to write to
  pipe <- conn_create_pipepair()
  on.exit(close(pipe[[1]]), add = TRUE)
  on.exit(close(pipe[[2]]), add = TRUE)

  p2 <- process$new(cmd[1], cmd[-1], stdout = pipe[[2]])
  on.exit(p2$kill(), add = TRUE)

  ready <- poll(list(pipe[[1]]), 3000)
  expect_equal(ready[[1]], "ready")
  lines <- conn_read_lines(pipe[[1]])
  # sometimes it takes more tried to read everything.
  deadline <- Sys.time() + as.difftime(3, units = "secs")
  while (Sys.time() < deadline && length(lines) < 2) {
    poll(list(pipe[[1]]), 1000)
    lines <- c(lines, conn_read_lines(pipe[[1]]))
  }
  expect_equal(lines, c("hello", "world"))
  p2$wait(3000)
  expect_false(p2$is_alive())
})

test_that("Passing connection to stderr", {
  # file first
  tmp <- tempfile()
  con <- conn_create_file(tmp, write = TRUE)
  cmd <- c(get_tool("px"), c("errln", "hello", "errln", "world"))

  p <- process$new(cmd[1], cmd[-1], stderr = con)
  on.exit(p$kill(), add = TRUE)
  close(con)

  p$wait(3000)
  expect_false(p$is_alive())

  err <- readLines(tmp)
  expect_equal(err, c("hello", "world"))

  # pass a pipe to write to
  pipe <- conn_create_pipepair()
  on.exit(close(pipe[[1]]), add = TRUE)
  on.exit(close(pipe[[2]]), add = TRUE)

  p2 <- process$new(cmd[1], cmd[-1], stderr = pipe[[2]])
  on.exit(p2$kill(), add = TRUE)
  close(pipe[[2]])

  ready <- poll(list(pipe[[1]]), 3000)
  expect_equal(ready[[1]], "ready")
  lines <- conn_read_lines(pipe[[1]])
  # sometimes it takes more tried to read everything.
  deadline <- Sys.time() + as.difftime(3, units = "secs")
  while (Sys.time() < deadline && length(lines) < 2) {
    poll(list(pipe[[1]]), 1000)
    lines <- c(lines, conn_read_lines(pipe[[1]]))
  }
  expect_equal(lines, c("hello", "world"))
  p2$wait(3000)
  expect_false(p2$is_alive())
})
