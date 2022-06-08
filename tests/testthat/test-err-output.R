
test_that("simple error", {

  out <- run_script({
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stderr))

  out <- run_script({
    options(rlib_interactive = TRUE)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stdout))
})

test_that("simple error with cli", {

  out <- run_script({
    library(cli)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stderr))

  out <- run_script({
    options(rlib_interactive = TRUE)
    library(cli)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stdout))
})

test_that("simple error with cli and colors", {

  out <- run_script({
    library(cli)
    options(cli.num_colors = 256)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stderr))

  out <- run_script({
    library(cli)
    options(rlib_interactive = TRUE)
    options(cli.num_colors = 256)
    f <- function() processx:::throw("This failed")
    f()
  })
  expect_snapshot(cat(out$stdout))
})

test_that("chain_error", {
  expr <- quote({
    options(cli.unicode = FALSE)
    do3 <- function() {
      processx:::throw("because of this")
    }

    do2 <- function() {
      processx:::chain_error(do3(), "something is wrong here")
    }

    do <- function() {
      processx:::chain_error(do2(), "Failed to base64 encode")
    }

    f <- function() g()
    g <- function() h()
    h <- function() do()
    f()
  })

  out <- run_script(quoted = expr)
  expect_snapshot(cat(out$stderr), transform = scrub_srcref)

  expr2 <- substitute(
    {o; c },
    list(o = quote(options(rlib_interactive = TRUE)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(cat(out$stdout))

  expr2 <- substitute(
    {o; c },
    list(o = quote(library(cli)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(cat(out$stderr), transform = scrub_srcref)

  expr2 <- substitute(
    {o; c },
    list(o = quote({library(cli); options(cli.num_colors = 256)}), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(cat(out$stderr), transform = scrub_srcref)
})

test_that("chain_error with stop()", {

  expr <- quote({
    do3 <- function() {
      stop("because of this")
    }

    do2 <- function() {
      processx:::chain_error(do3(), "something is wrong here")
    }

    do <- function() {
      processx:::chain_error(do2(), "Failed to base64 encode")
    }

    f <- function() g()
    g <- function() h()
    h <- function() do()
    f()
  })

  out <- run_script(quoted = expr)
  expect_snapshot(cat(out$stderr), transform = scrub_srcref)

  expr2 <- substitute(
    {o; c },
    list(o = quote(options(rlib_interactive = TRUE)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(cat(out$stdout))
})

test_that("chain_error with rlang::abort()", {

  expr <- quote({
    options(cli.unicode = FALSE)
    do3 <- function() {
      rlang::abort("because of this")
    }

    do2 <- function() {
      processx:::chain_error(do3(), "something is wrong here")
    }

    do <- function() {
      processx:::chain_error(do2(), "Failed to base64 encode")
    }

    f <- function() g()
    g <- function() h()
    h <- function() do()
    f()
  })

  out <- run_script(quoted = expr)
  expect_snapshot(cat(out$stderr), transform = scrub_srcref)

  expr2 <- substitute(
    {o; c },
    list(o = quote(options(rlib_interactive = TRUE)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(cat(out$stdout))
})

test_that("full parent error is printed in non-interactive mode", {
  expr <- quote({
    options(cli.unicode = FALSE)
    px <- processx:::get_tool("px")
    processx:::chain_error(
      processx::run(px, c("return", "1")),
      "failed to run external program"
    )
  })

  out <- run_script(quoted = expr)
  expect_snapshot(
    cat(out$stderr),
    transform = function(x) scrub_px(scrub_srcref(x))
  )

  expr2 <- substitute(
    {o; c },
    list(o = quote(options(rlib_interactive = TRUE)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(
    cat(out$stdout),
    transform = function(x) scrub_px(scrub_srcref(x))
  )

  expr2 <- substitute(
    {o; c },
    list(o = quote(library(cli)), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(
    cat(out$stderr),
    transform = function(x) scrub_px(scrub_srcref(x))
  )

  expr2 <- substitute(
    {o; c },
    list(o = quote({library(cli); options(cli.num_colors = 256)}), c = expr)
  )
  out <- run_script(quoted = expr2)
  expect_snapshot(
    cat(out$stderr),
    transform = function(x) scrub_px(scrub_srcref(x))
  )
})
