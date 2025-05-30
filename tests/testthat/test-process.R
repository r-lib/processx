test_that("process works", {
  px <- get_tool("px")
  p <- process$new(px, c("sleep", "5"))
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  expect_true(p$is_alive())
})

test_that("get_exit_status", {
  px <- get_tool("px")
  p <- process$new(px, c("return", "1"))
  on.exit(p$kill(), add = TRUE)
  p$wait()
  expect_identical(p$get_exit_status(), 1L)
})

test_that("non existing process", {
  expect_snapshot(
    error = TRUE,
    process$new(tempfile()),
    transform = transform_tempdir,
    variant = sysname()
  )
  ## This closes connections in finalizers
  gc()
})

test_that("post processing", {
  px <- get_tool("px")
  p <- process$new(
    px,
    c("return", "0"),
    post_process = function() "foobar"
  )
  p$wait(5000)
  p$kill()
  expect_equal(p$get_result(), "foobar")

  p <- process$new(
    px,
    c("sleep", "5"),
    post_process = function() "yep"
  )
  expect_snapshot(error = TRUE, p$get_result())
  p$kill()
  expect_equal(p$get_result(), "yep")

  ## Only runs once
  xx <- 0
  p <- process$new(
    px,
    c("return", "0"),
    post_process = function() xx <<- xx + 1
  )
  p$wait(5000)
  p$kill()
  p$get_result()
  expect_equal(xx, 1)
  p$get_result()
  expect_equal(xx, 1)
})

test_that("working directory", {
  px <- get_tool("px")
  dir.create(tmp <- tempfile())
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  cat("foo\nbar\n", file = file.path(tmp, "file"))

  p <- process$new(px, c("cat", "file"), wd = tmp, stdout = "|")
  on.exit(p$kill(), add = TRUE)
  p$wait()
  expect_equal(p$read_all_output_lines(), c("foo", "bar"))
})

test_that("working directory does not exist", {
  px <- get_tool("px")
  expect_snapshot(
    error = TRUE,
    process$new(px, wd = tempfile()),
    transform = transform_px,
    variant = sysname()
  )
  ## This closes connections in finalizers
  gc()
})

test_that("R process is installed with a SIGTERM cleanup handler", {
  # https://github.com/r-lib/callr/pull/250
  skip_if_not_installed("callr", "3.7.3.9001")

  # Needs POSIX signal handling
  skip_on_os("windows")

  # Enabled case
  withr::local_envvar(c(PROCESSX_R_SIGTERM_CLEANUP = "true"))

  out <- tempfile()

  fn <- function(file) {
    file.create(tempfile())
    writeLines(tempdir(), file)
  }

  p <- callr::r_session$new()
  p$run(fn, list(file = out))

  p_temp_dir <- readLines(out)
  expect_true(dir.exists(p_temp_dir))

  p$signal(ps::signals()$SIGTERM)
  p$wait()
  expect_false(dir.exists(p_temp_dir))

  # Disabled case
  withr::local_envvar(c(PROCESSX_R_SIGTERM_CLEANUP = NA_character_))

  # Just in case R adds tempdir cleanup on SIGTERM
  skip_on_cran()

  p <- callr::r_session$new()
  p$run(fn, list(file = out))

  p_temp_dir <- readLines(out)
  expect_true(dir.exists(p_temp_dir))

  p$signal(ps::signals()$SIGTERM)
  p$wait()

  # Was not cleaned up
  expect_true(dir.exists(p_temp_dir))
})
