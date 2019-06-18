
context("errors")

test_that("run() prints stderr if echo = FALSE", {
  px <- get_tool("px")
  err <- tryCatch(
    run(px, c("outln", "nopppp", "errln", "bad", "errln", "foobar",
              "return", "2")),
    error = function(e) e)
  expect_match(conditionMessage(err), "foobar")
  expect_false(any(grepl("nopppp", conditionMessage(err))))
})

test_that("run() omits stderr if echo = TRUE", {
  px <- get_tool("px")
  err <- tryCatch(
    capture.output(
      run(px, c("errln", "bad", "errln", "foobar", "return", "2"),
          echo = TRUE)),
    error = function(e) e)
  expect_false(any(grepl("foobar", conditionMessage(err))))
})

test_that("run() handles stderr_to_stdout = TRUE properly", {
  px <- get_tool("px")
  err <- tryCatch(
    run(px, c("outln", "nopppp", "errln", "bad", "errln", "foobar",
              "return", "2"), stderr_to_stdout = TRUE),
    error = function(e) e)
  expect_match(conditionMessage(err), "foobar")
  expect_match(conditionMessage(err), "nopppp")
})

test_that("run() only prints the last 10 lines of stderr", {
  px <- get_tool("px")
  args <- rbind("errln", paste0("foobar", 1:11, "--"))
  err <- tryCatch(
    run(px, c(args, "return", "2")),
    error = function(e) e)
  expect_false(any(grepl("foobar1--", conditionMessage(err))))
  expect_match(conditionMessage(err), "foobar2--")
  expect_match(conditionMessage(err), "foobar11--")
})
