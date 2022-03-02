
test_that("is_alive()", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))

    list(alive = px$is_alive(), status = px$get_exit_status())
  })

  expect_false(res$result$alive)
  expect_true(res$result$status %in% c(0L, NA_integer_))
})

test_that("finalizer", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))
    tryCatch({ rm(px); gc(); "OK" }, error = function(x) x)
  })

  expect_identical(res$result, "OK")
})

test_that("get_exit_status", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))
    px$get_exit_status()
  })

  expect_true(res$result %in% c(0L, NA_integer_))
})

test_that("signal", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))

    signal <- px$signal(2)              # SIGINT
    status <- px$get_exit_status()
    list(signal = signal, status = status)
  })

  # TRUE means that that signal was delivered, but it is different on
  # various Unix flavours. Some will deliver a SIGINT to a zombie, some
  # will not, so we don't test for this.
  expect_true(res$result$status %in% c(0L, NA_integer_))
})


test_that("kill", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))
    kill <- px$kill()
    status <- px$get_exit_status()
    list(kill = kill, status = status)
  })

  # FALSE means that that signal was not delivered
  expect_false(res$result$kill)
  expect_true(res$result$status %in% c(0L, NA_integer_))
})

test_that("SIGCHLD handler", {
  skip_other_platforms("unix")
  skip_on_cran()

  opts <- callr::r_session_options(
    env = c(PROCESSX_NOTIFY_OLD_SIGCHLD = "true")
  )
  rs <- callr::r_session$new(opts)
  on.exit(rs$close(), add = TRUE)

  res <- rs$run_with_output(function() {
    library(parallel)
    library(processx)

    px <- process$new("sleep", "0.5")
    on.exit(try(px$kill(), silent = TRUE), add = TRUE)

    p <- mcparallel(Sys.sleep(1))
    q <- mcparallel(Sys.sleep(1))
    res <- mccollect(list(p, q))

    out <- tryCatch({
      px2 <- process$new("true")
      px2$wait(1)
      "OK"
    }, error = function(e) e)

    list(out = out, status = px$get_exit_status())
  })

  expect_identical(res$result$out, "OK")
  expect_true(res$result$status %in% c(0L, NA_integer_))
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
  expect_equal(ret$status, 0)
  expect_equal(ret$stderr, "")
})

test_that("it is ok if parallel has no active cluster", {
  skip_on_cran()
  skip_other_platforms("unix")

  code <- substitute({
    cl <- parallel::makeForkCluster(2)
    if (getRversion() < "3.5.0") parallel::setDefaultCluster(cl)
    parallel::mclapply(1:2, function(x) x)

    job <- parallel::mcparallel(Sys.sleep(.5))
    processx::run("true")
    parallel::mccollect(job)

    # stop cluster, verify that we don't have subprocesses
    parallel::stopCluster(cl)
    print(ps::ps_children(ps::ps_handle()))

    # try to run sg, this still calls the old sigchld handler
    for (i in 1:5) processx::run("true")
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

  expect_equal(ret$status, 0)

  # R < 3.5.0 does not kill the subprocesses propery, it seems
  if (getRversion() >= "3.5.0") {
    expect_match(ret$stdout, "list()")
  } else {
    expect_true(TRUE)
  }
})
