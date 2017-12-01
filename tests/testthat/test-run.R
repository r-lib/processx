
context("run")

test_that("run can run, unix", {

  skip_other_platforms("unix")
  expect_equal(
    sort(strsplit(run("ls")$stdout, "\n")[[1]]),
    sort(list.files())
  )
})

test_that("run can run, windows", {

  skip_other_platforms("windows")

  expect_error({
    cmd <- sleep(0)
    run(cmd[1], cmd[-1])
  }, NA)
})

test_that("timeout works", {

  tic <- Sys.time()
  sl <- sleep(5)
  x <- run(sl[1], sl[-1], timeout = 0.00001, error_on_status = FALSE)
  toc <- Sys.time()

  expect_true(toc - tic < as.difftime(3, units = "secs"))
  expect_true(x$timeout)
})

test_that("timeout throws right error", {

  sl <- sleep(5)
  e <- tryCatch(
    run(sl[1], sl[-1], timeout = 0.00001, error_on_status = TRUE),
    error = function(e) e
  )

  expect_true("system_command_timeout_error" %in% class(e))
})

test_that("callbacks work, unix", {

  skip_other_platforms("unix")

  ## This typically freezes on Unix, if there is a malloc/free race
  ## condition in the SIGCHLD handler.
  for (i in 1:30) {
    out <- NULL
    run("ls", stdout_line_callback = function(x, ...) out <<- c(out, x))
  }
  expect_equal(sort(out), sort(list.files()))

  err <- NULL
  run(
    "ls", basename(tempfile()),
    stderr_line_callback = function(x, ...) err <<- c(err, x),
    error_on_status = FALSE
  )
  expect_match(paste(err, collapse = "\n"), "No such file")
})
