
context("run")

test_that("run can run", {

  px <- get_tool("px")
  expect_error({
    run(px, c("sleep", "0"))
  }, NA)
  gc()
})

test_that("timeout works", {

  px <- get_tool("px")
  tic <- Sys.time()
  x <- run(px, c("sleep", "5"), timeout = 0.00001, error_on_status = FALSE)
  toc <- Sys.time()

  expect_true(toc - tic < as.difftime(3, units = "secs"))
  expect_true(x$timeout)
  gc()
})

test_that("timeout throws right error", {

  px <- get_tool("px")
  e <- tryCatch(
    run(px, c("sleep", "5"), timeout = 0.00001, error_on_status = TRUE),
    error = function(e) e
  )

  expect_true("system_command_timeout_error" %in% class(e))
  gc()
})

test_that("callbacks work", {

  px <- get_tool("px")
  ## This typically freezes on Unix, if there is a malloc/free race
  ## condition in the SIGCHLD handler.
  for (i in 1:30) {
    out <- NULL
    run(
      px, rbind("outln", 1:20),
      stdout_line_callback = function(x, ...) out <<- c(out, x)
    )
    expect_equal(out, as.character(1:20))
    gc()
  }

  for (i in 1:30) {
    out <- NULL
    run(
      px, rbind("errln", 1:20),
      stderr_line_callback = function(x, ...) out <<- c(out, x),
      error_on_status = FALSE
    )
    expect_equal(out, as.character(1:20))
    gc()
  }
})

test_that("working directory", {
  px <- get_tool("px")
  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  cat("foo\nbar\n", file = file.path(tmp, "file"))

  x <- run(px, c("cat", "file"), wd = tmp)
  if  (is_windows()) {
    expect_equal(x$stdout, "foo\r\nbar\r\n")
  } else {
    expect_equal(x$stdout, "foo\nbar\n")
  }
  gc()
})

test_that("working directory does not exist", {
  px <- get_tool("px")
  expect_error(run(px, wd = tempfile()))
  gc()
})

test_that("stderr_to_stdout", {
  px <- get_tool("px")

  out <- run(
    px, c("out", "o1", "err", "e1", "out", "o2", "err", "e2", "outln", ""),
    stderr_to_stdout = TRUE)

  expect_equal(out$status, 0L)
  expect_equal(
    out$stdout, paste0("o1e1o2e2", if (is_windows()) "\r", "\n"))
  expect_equal(out$stderr, "")
  expect_false(out$timeout)
})

test_that("condition on interrupt", {
  skip_if_no_ps()
  skip_on_cran()
  skip_on_appveyor() # TODO: why does this fail?

  px <- get_tool("px")
  cnd <- tryCatch(
    interrupt_me(run(px, c("errln", "oops", "errflush", "sleep", 3)), 0.5),
    error = function(c) c,
    interrupt = function(c) c)

  expect_s3_class(cnd, "system_command_interrupt")
  expect_equal(str_trim(cnd$stderr), "oops")
})

test_that("stdin", {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)

  txt <- "foobar\nthis is the input\n"
  cat(txt, file = tmp)
  px <- get_tool("px")
  res <- run(px, c("cat", "<stdin>"), stdin = tmp)

  expect_equal(
    strsplit(res$stdout, "\r?\n")[[1]],
    c("foobar", "this is the input"))
})
