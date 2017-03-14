
context("run")

test_that("run can run, unix", {

  skip_other_platforms("unix")
  expect_equal(
    sort(run("ls")$stdout),
    sort(list.files())
  )
})

test_that("run can run, windows", {

  skip_other_platforms("windows")

  expect_silent(
    run("ping", c("-n", "1", "127.0.0.1"))
  )
})

test_that("timeout works, unix", {

  skip_other_platforms("unix")

  tic <- Sys.time()
  x <- run(
    commandline = "sleep 5",
    timeout = 0.01,
    error_on_status = FALSE
  )
  toc <- Sys.time()

  expect_true(toc - tic < as.difftime(3, units = "secs"))
})

test_that("callbacks work, unix", {

  skip_other_platforms("unix")

  out <- NULL
  run("ls", stdout_callback = function(x, ...) out <<- c(out, x))
  expect_equal(sort(out), sort(list.files()))

  err <- NULL
  run(
    "ls", basename(tempfile()),
    stderr_callback = function(x, ...) err <<- c(err, x),
    error_on_status = FALSE
  )
  expect_match(paste(err, collapse = "\n"), "No such file")
})
