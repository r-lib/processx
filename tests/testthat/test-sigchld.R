
context("SIGCHLD handler interference")

test_that("is_alive()", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))
  expect_false(px$is_alive())
  expect_true(px$get_exit_status() %in% c(0L, NA_integer_))
})

test_that("finalizer", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))
  expect_error({ rm(px); gc() }, NA)
})

test_that("get_exit_status", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))
  expect_true(px$get_exit_status() %in% c(0L, NA_integer_))
})

test_that("signal", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))
  expect_false(px$signal(2))            # SIGINT
  expect_true(px$get_exit_status() %in% c(0L, NA_integer_))
})

test_that("kill", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))
  expect_false(px$kill())
  expect_true(px$get_exit_status() %in% c(0L, NA_integer_))
})

test_that("SIGCHLD handler", {

  skip_extra_tests()
  skip_other_platforms("unix")
  skip_on_cran()

  library(parallel)

  px <- process$new("sleep", "0.1")
  on.exit(try(px$kill(), silent = TRUE), add = TRUE)

  p <- mcparallel(Sys.sleep(0.2))
  q <- mcparallel(Sys.sleep(0.2))
  res <- mccollect(list(p, q))

  expect_error({
    px2 <- process$new("true")
    on.exit(try(px2$kill(), silent = TRUE), add = TRUE)
    px2$wait(1)
  }, NA)

  expect_true(px$get_exit_status() %in% c(0L, NA_integer_))
})

test_that("Notify old signal handler", {
  skip_on_cran()
  skip_other_platforms("unix")

  code <- substitute({
    # Create cluster, check that it works
    cl <- parallel::makeForkCluster(2)
    parallel::mclapply(1:2, function(x) x)

    # Run a parallel background job
    job <- parallel::mcparallel(Sys.sleep(.5))

    # Start processx process, it will overwrite the signal handler
    processx::run("true")

    # Wait for parallel job to finish
    parallel::mccollect(job)
  })

  script <- tempfile(pattern = "processx-test-", fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  cat(deparse(code), sep = "\n", file = script)

  env <- c(callr::rcmd_safe_env(), PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  ret <- callr::rscript(
    script,
    env = env,
    fail_on_status = FALSE,
    show = FALSE,
    timeout = 5
  )

  # parallel sends a message to stderr, complaining about unable to
  # to terminate some child processes. That should not happen any more.
  expect_equal(ret$stderr, "")
})

test_that("it is ok if parallel has no active cluster", {
  skip_on_cran()
  skip_other_platforms("unix")

  code <- substitute({
    cl <- parallel::makeForkCluster(2)
    parallel::mclapply(1:2, function(x) x)

    job <- parallel::mcparallel(Sys.sleep(.5))
    processx::run("true")
    parallel::mccollect(job)

    # stop cluster, verify that we don't have subprocesses
    parallel::stopCluster(cl)
    print(ps::ps_children(ps::ps_handle()))

    # try to run sg, this still calls the old sigchld handler
    for (i in 1:5) processx::run("true")

    # No cluster, just to clarify
    print(parallel::getDefaultCluster())
  })

  script <- tempfile(pattern = "processx-test-", fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  cat(deparse(code), sep = "\n", file = script)

  env <- c(callr::rcmd_safe_env(), PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  ret <- callr::rscript(
    script,
    env = env,
    fail_on_status = FALSE,
    show = FALSE
  )

  expect_equal(ret$status, 0)
  expect_match(ret$stdout, "list()")
  expect_match(ret$stdout, "NULL")
})
