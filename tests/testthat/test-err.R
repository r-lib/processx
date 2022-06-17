
test_that("throw() is standalone", {
  stenv <- environment(throw)
  objs <- ls(stenv, all.names = TRUE)
  funs <- Filter(function(x) is.function(stenv[[x]]), objs)
  funobjs <- mget(funs, stenv)
  for (f in funobjs) expect_identical(environmentName(topenv(f)), "base")

  expect_message(
    withCallingHandlers(
      res <- mapply(codetools::checkUsage, funobjs, funs,
                    MoreArgs = list(report = message)),
      message = function(c) {
        if (grepl(".hide_from_trace", c$message)) {
          invokeRestart("muffleMessage")
        }
      }
    ),
    NA
  )
})

test_that("new_cond", {
  c <- new_cond("foo", "bar")
  expect_identical(class(c), "condition")
  expect_identical(c$message, "foobar")
})

test_that("new_error", {
  c <- new_error("foo", "bar")
  expect_identical(
    class(c),
    c("rlib_error_3_0", "rlib_error", "error", "condition")
  )
  expect_identical(c$message, "foobar")
})

test_that("throw() works with condition objects or strings", {
  expect_error(
    throw("foobar"), "foobar",
    class = "rlib_error")
  expect_error(
    throw(new_error("foobar")), "foobar",
    class = "rlib_error")
})

test_that("parent must be an error object", {
  expect_error(
    throw(new_error("foobar"), parent = "nope"),
    "Parent condition must be a condition object",
    class = "rlib_error")
})

test_that("throw() adds the proper call, if requested", {
  f <- function() throw(new_error("ooops"))
  err <- tryCatch(f(), error = function(e) e)
  expect_s3_class(err, "rlib_error")
  expect_identical(err$call, "f()")

  g <- function() throw(new_error("ooops", call. = FALSE))
  err <- tryCatch(g(), error = function(e) e)
  expect_s3_class(err, "rlib_error")
  expect_null(err$call)
})

test_that("throw() only stops for errors", {
  f <- function() throw(new_cond("nothing important"))

  expect_error(f(), NA)
})

test_that("caught conditions have no trace", {
  f <- function() throw(new_error("nothing important"))

  cond <- tryCatch(f(), condition = function(e) e)
  expect_null(cond$trace)
})

test_that("un-caught condition has trace", {

  skip_on_cran()

  # We need to run this in a separate script, because
  # testthat catches all conditions. We also cannot run it in callr::r()
  # or similar, because those catch conditions as well.

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    f <- function() g()
    g <- function() processx:::throw(processx:::new_error("oooops"))
    options(rlib_error_handler = function(c) {
      saveRDS(c, file = `__op__`)
    })
    f()
  }, list("__op__" = op))

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(sf, stdout = so, stderr = se)

  cond <- readRDS(op)
  expect_s3_class(cond, "rlib_error")
  expect_s3_class(cond$trace, "rlib_trace")
})

test_that("chain_call", {

  do <- function() {
    chain_call(c_processx_base64_encode, "foobar")
  }
  cond <- tryCatch(
   do(),
   error = function(e) e
  )

  expect_equal(cond$call, "do()")
  expect_s3_class(cond, "c_error")
  expect_s3_class(cond, "rlib_error")
})

test_that("errors from subprocess", {
  skip_if_not_installed("callr", minimum_version = "3.7.0")
  if (packageVersion("callr") != "3.7.0") skip("only with callr 3.7.0")
  err <- tryCatch(
    callr::r(function() 1 + "a"),
    error = function(e) e)
  expect_s3_class(err, "rlib_error")
  expect_s3_class(err$parent, "error")
  expect_false(is.null(err$parent$trace))
})

test_that("errors from subprocess", {
  skip_if_not_installed("callr", minimum_version = "3.7.0.9000")
  err <- tryCatch(
    callr::r(function() 1 + "a"),
    error = function(e) e)
  expect_s3_class(err, "rlib_error")
  expect_s3_class(err$parent, "error")
  expect_false(is.null(err$parent_trace))
})

test_that("error trace from subprocess", {
  skip_on_cran()
  skip_if_not_installed("callr", minimum_version = "3.7.0")
  if (packageVersion("callr") != "3.7.0") skip("only with callr 3.7.0")

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    h <- function() callr::r(function() 1 + "a")
    options(rlib_error_handler = function(c) {
      saveRDS(c, file = `__op__`)
      # quit after the first, because the other one is caught here as well
      q()
    })
    h()
  }, list("__op__" = op))

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(sf, stdout = so, stderr = se)

  cond <- readRDS(op)

  expect_s3_class(cond, "rlib_error")
  expect_s3_class(cond$parent, "error")
  expect_s3_class(cond$trace, "rlib_trace")

  expect_equal(length(cond$trace$nframe), 2)
  expect_true(cond$trace$nframe[1] < cond$trace$nframe[2])
  expect_match(cond$trace$messages[[1]], "subprocess failed: non-numeric")
  expect_match(cond$trace$messages[[2]], "non-numeric argument")
})

test_that("error trace from subprocess", {
  skip_on_cran()
  skip_if_not_installed("callr", minimum_version = "3.7.0.9000")

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    h <- function() callr::r(function() 1 + "a")
    options(rlib_error_handler = function(c) {
      saveRDS(c, file = `__op__`)
      # quit after the first, because the other one is caught here as well
      q()
    })
    h()
  }, list("__op__" = op))

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(sf, stdout = so, stderr = se)

  cond <- readRDS(op)

  expect_s3_class(cond, "rlib_error")
  expect_s3_class(cond$parent, "error")
  expect_s3_class(cond$trace, "rlib_trace")
})

test_that("error trace from throw() in subprocess", {
  skip_on_cran()
  skip_if_not_installed("callr", minimum_version = "3.7.0")
  if (packageVersion("callr") != "3.7.0") skip("only with callr 3.7.0")

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    h <- function() callr::r(function() processx::run("does-not-exist---"))
    options(rlib_error_handler = function(c) {
      saveRDS(c, file = `__op__`)
      # quit after the first, because the other one is caught here as well
      q()
    })
    h()
  }, list("__op__" = op))

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(sf, stdout = so, stderr = se)

  cond <- readRDS(op)

  expect_s3_class(cond, "rlib_error")
  expect_s3_class(cond$parent, "rlib_error")
  expect_s3_class(cond$trace, "rlib_trace")

  expect_equal(length(cond$trace$nframe), 2)
  expect_true(cond$trace$nframe[1] < cond$trace$nframe[2])
  expect_match(cond$trace$messages[[1]], "subprocess failed: .*processx\\.c")
  expect_match(cond$trace$messages[[2]], "@.*processx\\.c")
})

test_that("error trace from throw() in subprocess", {
  skip_on_cran()
  skip_if_not_installed("callr", minimum_version = "3.7.0.9000")

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    h <- function() callr::r(function() processx::run("does-not-exist---"))
    options(rlib_error_handler = function(c) {
      saveRDS(c, file = `__op__`)
      # quit after the first, because the other one is caught here as well
      q()
    })
    h()
  }, list("__op__" = op))

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(sf, stdout = so, stderr = se)

  cond <- readRDS(op)

  expect_s3_class(cond, "rlib_error")
  expect_s3_class(cond$parent, "rlib_error")
  expect_s3_class(cond$trace, "rlib_trace")
})

test_that("trace is not overwritten", {
  skip_on_cran()
  withr::local_options(list(rlib_error_always_trace = TRUE))
  err <- new_error("foobar")
  err$trace <- "not really"

  err2 <- tryCatch(throw(err), error = function(e) e)
  expect_identical(err2$trace, "not really")
})

test_that("error is printed on error", {
  skip_on_cran()

  sf <- tempfile(fileext = ".R")
  op <- sub("\\.R$", ".rds", sf)
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, op, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    options(rlib_interactive = TRUE)
    processx::run(basename(tempfile()))
  })

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(
    sf,
    stdout = so,
    stderr = se,
    fail_on_status = FALSE,
    show = FALSE
  )

  selines <- readLines(so)
  expect_true(
    any(grepl("No such file or directory", selines)) ||
    any(grepl("Command .* not found", selines))
  )
  expect_false(any(grepl("Stack trace", selines)))
})

test_that("trace is printed on error in non-interactive sessions", {

  sf <- tempfile(fileext = ".R")
  so <- paste0(sf, "out")
  se <- paste0(sf, "err")
  on.exit(unlink(c(sf, so, se), recursive = TRUE), add = TRUE)

  expr <- substitute({
    processx::run(basename(tempfile()))
  })

  cat(deparse(expr), file = sf, sep = "\n")

  callr::rscript(
    sf,
    stdout = so,
    stderr = se,
    fail_on_status = FALSE,
    show = FALSE
  )

  selines <- readLines(se)
  expect_true(
    any(grepl("No such file or directory", selines)) ||
      any(grepl("Command .* not found", selines))
  )
  expect_true(any(grepl("Backtrace", selines)))
})
