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
  skip_if_no_srcrefs()
  withr::local_options(width = 400)
  expect_snapshot(
    error = TRUE,
    process$new(tempfile()),
    transform = function(x) transform_line_number(transform_tempdir(x)),
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
  skip_if_no_srcrefs()
  px <- get_tool("px")
  expect_snapshot(
    error = TRUE,
    process$new(px, wd = tempfile()),
    transform = function(x) transform_line_number(transform_px(x)),
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
  withr::defer(unlink(out, TRUE, TRUE))

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

  retry_until(function() !dir.exists(p_temp_dir))

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

test_that("can kill process tree with SIGTERM", {
  # https://github.com/r-lib/callr/pull/250
  skip_if_not_installed("callr", "3.7.3.9001")

  # Needs POSIX signal handling
  skip_on_os("windows")

  # fork() in signal handler can deadlock under ASAN; shutdown is too slow
  # for the poll timeout under UBSAN and valgrind
  skip_if(is_asan())
  skip_if(is_ubsan())
  skip_if(is_valgrind())

  withr::local_envvar(c(PROCESSX_R_SIGTERM_CLEANUP = "true"))

  out <- tempfile()
  withr::defer(unlink(out, TRUE, TRUE))
  file.create(out)

  fn <- function(recurse, local, file) {
    p <- NULL

    if (recurse) {
      p <- callr::r_session$new()
      p$call(
        sys.function(),
        list(recurse - 1, local = FALSE, file = file)
      )
    }

    if (!local) {
      file.create(tempfile())
      cat(paste0(tempdir(), "\n"), file = file, append = TRUE)

      # Sleeping prevents the process to receive an EOF in
      # `R_ReadConsole()` (which causes it to quit normally)
      Sys.sleep(60)
    }

    p
  }

  N <- 5
  p <- fn(N, local = TRUE, file = out)

  pid <- p$get_pid()
  id <- p$.__enclos_env__$private$tree_id

  temp_dirs <- NULL

  retry_until(function() {
    temp_dirs <<- readLines(out)
    length(temp_dirs) == N
  })

  ps <- ps::ps_find_tree(id)

  for (p in ps) {
    tools::pskill(ps::ps_pid(p))
  }
  retry_until(function() {
    !any(sapply(ps, function(p) ps::ps_is_running(p)))
  })

  # rm -rf runs in a forked child; poll until it finishes
  retry_until(function() !any(dir.exists(temp_dirs)))
  expect_false(any(dir.exists(temp_dirs)))
})


test_that("linux_pdeathsig kills child when parent exits", {
  skip_if(!is_linux())
  skip_if(is_valgrind())
  skip_if(is_asan())
  skip_if(is_ubsan())
  skip_on_cran()

  px <- get_tool("px")
  pidfile <- tempfile()
  on.exit(unlink(pidfile), add = TRUE)

  # Start a long-lived parent that spawns a grandchild with linux_pdeathsig
  # and writes its PID to a file, then sleeps. We SIGKILL the parent
  # explicitly — instantaneous, no sanitizer cleanup delay — so PDEATHSIG
  # fires at a known time regardless of ASAN/valgrind overhead.
  bg <- callr::r_bg(
    function(px, pidfile) {
      p <- processx::process$new(
        px,
        c("sleep", "100"),
        cleanup = FALSE,
        linux_pdeathsig = TRUE
      )
      writeLines(as.character(p$get_pid()), pidfile)
      Sys.sleep(600)
    },
    args = list(px = px, pidfile = pidfile)
  )
  on.exit(bg$kill(), add = TRUE)

  deadline <- get_deadline(secs = 5)
  while (!file.exists(pidfile) && Sys.time() < deadline) {
    Sys.sleep(0.05)
  }
  skip_if(!file.exists(pidfile), "grandchild did not start in time")
  grandchild_pid <- as.integer(readLines(pidfile))
  on.exit(tools::pskill(grandchild_pid, tools::SIGKILL), add = TRUE)

  bg$kill()
  bg$wait()

  deadline <- get_deadline(secs = 3)
  while (process__exists(grandchild_pid) && Sys.time() < deadline) {
    Sys.sleep(0.05)
  }
  expect_false(process__exists(grandchild_pid))
})

test_that("without linux_pdeathsig child survives parent exit", {
  skip_if(!is_linux())
  skip_if(is_valgrind())
  skip_if(is_asan())
  skip_if(is_ubsan())
  skip_on_cran()

  px <- get_tool("px")
  pidfile <- tempfile()
  on.exit(unlink(pidfile), add = TRUE)

  bg <- callr::r_bg(
    function(px, pidfile) {
      p <- processx::process$new(
        px,
        c("sleep", "100"),
        cleanup = FALSE,
        linux_pdeathsig = FALSE
      )
      writeLines(as.character(p$get_pid()), pidfile)
      Sys.sleep(600)
    },
    args = list(px = px, pidfile = pidfile)
  )
  on.exit(bg$kill(), add = TRUE)

  deadline <- get_deadline(secs = 5)
  while (!file.exists(pidfile) && Sys.time() < deadline) {
    Sys.sleep(0.05)
  }
  skip_if(!file.exists(pidfile), "grandchild did not start in time")
  grandchild_pid <- as.integer(readLines(pidfile))
  on.exit(tools::pskill(grandchild_pid, tools::SIGKILL), add = TRUE)

  bg$kill()
  bg$wait()

  Sys.sleep(0.2)
  expect_true(process__exists(grandchild_pid))
})

test_that("linux_pdeathsig input validation", {
  px <- get_tool("px")

  # Valid: FALSE (default)
  p <- process$new(px, c("return", "0"), linux_pdeathsig = FALSE)
  p$wait()

  # Valid signal numbers are accepted on all platforms; non-Linux just warns
  if (is_linux()) {
    p <- process$new(px, c("return", "0"), linux_pdeathsig = TRUE)
    p$wait()
    p <- process$new(px, c("return", "0"), linux_pdeathsig = tools::SIGTERM)
    p$wait()
  } else {
    expect_warning(
      process$new(px, c("return", "0"), linux_pdeathsig = TRUE)$wait(),
      "ignored on non-Linux"
    )
  }

  # Invalid: string, negative, zero
  expect_error(process$new(px, c("return", "0"), linux_pdeathsig = "foo"))
  expect_error(process$new(px, c("return", "0"), linux_pdeathsig = -1))
  expect_error(process$new(px, c("return", "0"), linux_pdeathsig = 0))
})

test_that("get_end_time", {
  px <- get_tool("px")

  p <- process$new(px, c("sleep", "1"))
  on.exit(p$kill(), add = TRUE)

  before <- Sys.time()
  expect_null(p$get_end_time())

  p$wait()
  after <- Sys.time()

  et <- p$get_end_time()
  expect_s3_class(et, "POSIXct")
  expect_gte(as.double(et), as.double(before))
  expect_gte(as.double(et), as.double(p$get_start_time()))

  # cached: second call returns the same value
  expect_equal(p$get_end_time(), et)
})

test_that("can kill process with grace", {
  # https://github.com/r-lib/callr/pull/250
  skip_on_os("windows")
  skip_if_not_installed("callr", "3.7.3.9001")

  withr::local_envvar("PROCESSX_R_SIGTERM_CLEANUP" = "true")

  # Write subprocess `tempdir()` to this file
  out <- tempfile()
  defer(rimraf(out))

  fn <- function(file) {
    file.create(tempfile())
    cat(paste0(tempdir(), "\n"), file = file)
  }
  get_temp_dir <- function(frame = parent.frame()) {
    dir <- readLines(out)
    expect_length(dir, 1)
    defer(rimraf(dir), frame = frame)
    dir
  }

  # Check that SIGTERM was called on subprocess by examining side
  # effect of tempdir cleanup
  p <- callr::r_session$new()
  p$run(fn, list(file = out))
  dir <- get_temp_dir()
  p$kill(grace = 0.1)
  retry_until(function() !dir.exists(dir))

  # When `grace` is 0, the tempdir isn't cleaned up
  p <- callr::r_session$new()
  p$run(fn, list(file = out))
  dir <- get_temp_dir()
  p$kill(grace = 0)
  expect_true(dir.exists(dir))
})

test_that("can use custom `cleanup_signal`", {
  # https://github.com/r-lib/callr/pull/250
  skip_if_not_installed("callr", "3.7.4")

  withr::local_envvar("PROCESSX_R_SIGTERM_CLEANUP" = "true")

  # Should become the default in callr
  opts <- callr::r_process_options(
    extra = list(
      cleanup_grace = 0.1
    )
  )
  p <- callr::r_session$new(opts)

  out <- tempfile()
  defer(rimraf(out))

  fn <- function(file) {
    file.create(tempfile())
    writeLines(tempdir(), file)
  }
  p$run(fn, list(file = out))

  dir <- readLines(out)
  defer(rimraf(dir))

  # Needs POSIX signals
  skip_on_os("windows")

  # GC `p` to trigger finalizer; R doesn't guarantee finalizers run on a
  # single gc(), so we retry until the side-effect is observed
  rm(p)
  retry_until(function() {
    gc()
    !dir.exists(dir)
  })
})

test_that("can load sigtermignore", {
  skip_on_os("windows")
  p <- callr::r_session$new()
  defer(p$kill())

  p$run(load_sigtermignore)

  tools::pskill(p$get_pid(), tools::SIGTERM)
  tools::pskill(p$get_pid(), tools::SIGTERM)

  expect_true(p$is_alive())
})

test_that("can kill with SIGTERM when ignored", {
  skip_on_os("windows")
  p <- callr::r_session$new()
  defer(p$kill())

  p$run(load_sigtermignore)

  p$signal(tools::SIGTERM)
  Sys.sleep(0.05)
  expect_true(p$is_alive())
})
