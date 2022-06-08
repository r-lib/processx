
test_that("run() prints stderr if echo = FALSE", {
  px <- get_tool("px")
  err <- tryCatch(
    run(px, c("outln", "nopppp", "errln", "bad", "errln", "foobar",
              "return", "2")),
    error = function(e) e)
  expect_true(any(grepl("foobar", format(err))))
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
  expect_true(any(grepl("foobar", format(err))))
  expect_true(any(grepl("nopppp", format(err))))
})

test_that("run() only prints the last 10 lines of stderr", {
  px <- get_tool("px")
  args <- rbind("errln", paste0("foobar", 1:11, "--"))
  withr::with_options(
    list(rlib_interactive = TRUE),
    ferr <- format(tryCatch(
      run(px, c(args, "return", "2")),
      error = function(e) e))
  )
  expect_false(any(grepl("foobar1--", ferr)))
  expect_true(any(grepl("foobar2--", ferr)))
  expect_true(any(grepl("foobar11--", ferr)))
})

test_that("prints full stderr in non-interactive mode", {
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script, recursive = TRUE), add = TRUE)

  code <- quote({
    px <- asNamespace("processx")$get_tool("px")
    args <- rbind("errln", paste0("foobar", 1:20, "--"))
    processx::run(px, c(args, "return", "2"))
  })
  cat(deparse(code), file = script, sep = "\n")

  out <- callr::rscript(script, fail_on_status = FALSE, show = FALSE)
  expect_match(out$stderr, "foobar1--")
  expect_match(out$stderr, "foobar20--")
})

test_that("output from error", {

  out <- run_script({
    processx::run(
      processx:::get_tool("px"),
      c("errln", paste(1:20, collapse = "\n"), "return", "100")
    )
  })

  expect_snapshot(
    cat(out$stderr),
    transform = function(x) scrub_px(scrub_srcref(x))
  )
})
