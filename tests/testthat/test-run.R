test_that("run can run", {
  px <- get_tool("px")
  expect_error(
    {
      run(px, c("sleep", "0"))
    },
    NA
  )
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
      px,
      rbind("outln", 1:20),
      stdout_line_callback = function(x, ...) out <<- c(out, x)
    )
    expect_equal(out, as.character(1:20))
    gc()
  }

  for (i in 1:30) {
    out <- NULL
    run(
      px,
      rbind("errln", 1:20),
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
  if (is_windows()) {
    expect_equal(x$stdout, "foo\r\nbar\r\n")
  } else {
    expect_equal(x$stdout, "foo\nbar\n")
  }
  gc()
})

test_that("working directory does not exist", {
  skip_if_no_srcrefs()
  px <- get_tool("px")
  expect_snapshot(
    error = TRUE,
    run(px, wd = tempfile()),
    transform = function(x) transform_column_number(transform_px(x)),
    variant = sysname()
  )
  gc()
})

test_that("stderr_to_stdout", {
  px <- get_tool("px")

  out <- run(
    px,
    c("out", "o1", "err", "e1", "out", "o2", "err", "e2", "outln", ""),
    stderr_to_stdout = TRUE
  )

  expect_equal(out$status, 0L)
  expect_equal(
    out$stdout,
    paste0("o1e1o2e2", if (is_windows()) "\r", "\n")
  )
  expect_equal(out$stderr, NULL)
  expect_false(out$timeout)
})

test_that("condition on interrupt", {
  skip_if_no_ps()
  skip_on_cran()
  if (is_windows() && Sys.getenv("_R_CHECK_PACKAGE_NAME_", "") != "") {
    skip("Fails in Windows R CMD check")
  }

  px <- get_tool("px")
  cnd <- tryCatch(
    interrupt_me(run(px, c("errln", "oops", "errflush", "sleep", 3)), 0.5),
    error = function(c) c,
    interrupt = function(c) c
  )

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
    c("foobar", "this is the input")
  )
})

test_that("drop stdout", {
  px <- get_tool("px")
  res <- run(px, c("out", "boo", "err", "bah"), stdout = NULL)
  expect_null(res$stdout)
  expect_equal(res$stderr, "bah")
})

test_that("drop stderr", {
  px <- get_tool("px")
  res <- run(px, c("out", "boo", "err", "bah"), stderr = NULL)
  expect_equal(res$stdout, "boo")
  expect_null(res$stderr)
})

test_that("drop std*", {
  px <- get_tool("px")
  res <- run(px, c("out", "boo", "err", "bah"), stdout = NULL, stderr = NULL)
  expect_null(res$stdout)
  expect_null(res$stderr)
})

test_that("redirect stout", {
  tmp1 <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp1, tmp2)), add = TRUE)

  px <- get_tool("px")
  res <- run(
    px,
    c("outln", "boo", "errln", "bah"),
    stdout = tmp1,
    stderr = tmp2
  )
  expect_null(res$stdout)
  expect_null(res$stderr)
  expect_equal(readLines(tmp1), "boo")
  expect_equal(readLines(tmp2), "bah")
})

test_that("binary=TRUE captures stdout as raw vector", {
  skip_on_cran()

  # Include null byte, high bytes, \r\n — bytes text mode would mangle
  hex <- "00010a0d0d0a80ff"
  expected <- as.raw(c(0x00, 0x01, 0x0a, 0x0d, 0x0d, 0x0a, 0x80, 0xff))

  px <- get_tool("px")
  res <- run(px, c("rawout", hex), encoding = "binary")

  expect_identical(res$stdout, expected)
  expect_identical(res$stderr, raw(0))
})

test_that("binary=TRUE captures stderr as raw vector", {
  skip_on_cran()

  hex <- "00010a0d0d0a80ff"
  expected <- as.raw(c(0x00, 0x01, 0x0a, 0x0d, 0x0d, 0x0a, 0x80, 0xff))

  px <- get_tool("px")
  res <- run(
    px,
    c("rawerr", hex),
    encoding = "binary",
    error_on_status = FALSE
  )

  expect_identical(res$stdout, raw(0))
  expect_identical(res$stderr, expected)
})

test_that("binary=TRUE with stdout_callback receives raw chunks", {
  skip_on_cran()

  hex <- "00010a80ff"
  expected <- as.raw(c(0x00, 0x01, 0x0a, 0x80, 0xff))

  px <- get_tool("px")
  chunks <- list()
  res <- run(
    px,
    c("rawout", hex),
    encoding = "binary",
    stdout_callback = function(x, ...) chunks[[length(chunks) + 1]] <<- x
  )

  combined <- do.call(c, chunks)
  expect_identical(combined, expected)
  expect_identical(res$stdout, expected)
})

test_that("binary=TRUE errors with line callbacks", {
  px <- get_tool("px")
  expect_snapshot(error = TRUE,
    run(px, "out", encoding = "binary", stdout_line_callback = function(x, ...) x)
  )
  expect_snapshot(error = TRUE,
    run(px, "out", encoding = "binary", stderr_line_callback = function(x, ...) x)
  )
})

test_that("pty=TRUE collects merged output in stdout", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  res <- run("echo", c("hello", "pty"), pty = TRUE)
  expect_match(res$stdout, "hello pty")
  expect_null(res$stderr)
})

test_that("pty=TRUE works with stdout_callback", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  chunks <- character()
  res <- run(
    "echo", "hello",
    pty = TRUE,
    stdout_callback = function(x, ...) chunks <<- c(chunks, x)
  )
  expect_match(paste(chunks, collapse = ""), "hello")
  expect_null(res$stderr)
})

test_that("pty=TRUE errors on incompatible arguments", {
  skip_on_cran()
  expect_snapshot(error = TRUE, run("echo", pty = TRUE, stdout = NULL))
  expect_snapshot(error = TRUE, run("echo", pty = TRUE, stderr = NULL))
  expect_snapshot(error = TRUE,
    run("echo", pty = TRUE, stderr_to_stdout = TRUE)
  )
  expect_snapshot(error = TRUE,
    run("echo", pty = TRUE, stderr_callback = function(x, ...) x)
  )
  expect_snapshot(error = TRUE,
    run("echo", pty = TRUE, stderr_line_callback = function(x, ...) x)
  )
  expect_snapshot(error = TRUE,
    run("echo", pty = TRUE, stdin = "|")
  )
})

test_that("pty=TRUE with file stdin feeds content to the process", {
  skip_other_platforms("unix")
  skip_on_os("solaris")
  skip_on_cran()

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c("hello", "world"), tmp)

  res <- run("cat", pty = TRUE, stdin = tmp)
  expect_match(res$stdout, "hello")
  expect_match(res$stdout, "world")
  expect_null(res$stderr)
})
