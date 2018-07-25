
context("kill_tree")

test_that("tree ids are inherited", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"))
  on.exit(p$kill(), add = TRUE)
  ep <- ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)

  ## On Windows, if the process hasn't been initialized yet,
  ## this will return ERROR_PARTIAL_COPY (System error 299).
  ## Until this is fixed in ps, we just retry a couple of times.
  env <- "failed"
  deadline <- Sys.time() + 3
  while (TRUE) {
    if (Sys.time() >= deadline) break
    tryCatch({
      env <- ps::ps_environ(ep)[[ev]]
      break },
      error = function(e) e)
    Sys.sleep(0.05)
  }

  expect_true(Sys.time() < deadline)
  expect_equal(env, "YES")
})

test_that("tree ids are inherited if env is specified", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"), env = c(FOO = "bar"))
  on.exit(p$kill(), add = TRUE)

  ep <-  ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)

  ## On Windows, if the process hasn't been initialized yet,
  ## this will return ERROR_PARTIAL_COPY (System error 299).
  ## Until this is fixed in ps, we just retry a couple of times.
  env <- "failed"
  deadline <- Sys.time() + 3
  while (TRUE) {
    if (Sys.time() >= deadline) break
    tryCatch({
      env <- ps::ps_environ(ep)[[ev]]
      break },
      error = function(e) e)
    Sys.sleep(0.05)
  }

  expect_true(Sys.time() < deadline)
  expect_equal(ps::ps_environ(ep)[[ev]], "YES")
  expect_equal(ps::ps_environ(ep)[["FOO"]], "bar")
})

test_that("kill_tree", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "100"))
  on.exit(p$kill(), add = TRUE)

  res <- p$kill_tree()
  expect_true(any(c("px", "px.exe") %in% names(res)))
  expect_true(p$get_pid() %in% res)

  deadline <- Sys.time() + 1
  while (p$is_alive() && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_false(p$is_alive())
})

test_that("kill_tree with children", {
  skip_on_cran()
  skip_if_no_ps()

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  p <- callr::r_bg(
    function(px, tmp) {
      processx::run(px, c("outln", "ok", "sleep", "100"),
        stdout_callback = function(x, p) cat(x, file = tmp, append = TRUE))
    },
    args = list(px = get_tool("px"), tmp = tmp)
  )

  deadline <- Sys.time() + 2
  while (!file.exists(tmp) && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)

  res <- p$kill_tree()
  expect_true(any(c("px", "px.exe") %in% names(res)))
  expect_true(any(c("R", "Rterm.exe") %in% names(res)))
  expect_true(p$get_pid() %in% res)

  deadline <- Sys.time() + 1
  while (p$is_alive() && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_false(p$is_alive())
})

test_that("kill_tree and orphaned children", {
  skip_on_cran()
  skip_if_no_ps()

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  p1 <- callr::r_bg(
    function(px, tmp) {
      p <- processx::process$new(px, c("outln", "ok", "sleep", "100"),
        stdout = tmp, cleanup = FALSE)
      list(pid = p$get_pid(), create_time = p$get_start_time(),
           id = p$.__enclos_env__$private$tree_id)
    },
    args = list(px = get_tool("px"), tmp = tmp)
  )

  p1$wait()
  pres <- p1$get_result()

  ps <- ps::ps_handle(pres$pid)
  expect_true(ps::ps_is_running(ps))

  deadline <- Sys.time() + 2
  while ((!file.exists(tmp) || file_size(tmp) == 0) &&
         Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)

  res <- p1$kill_tree(pres$id)
  expect_true(any(c("px", "px.exe") %in% names(res)))

  deadline <- Sys.time() + 1
  while (ps::ps_is_running(ps) && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_false(ps::ps_is_running(ps))
})

test_that("cleanup_tree option", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "100"), cleanup_tree = TRUE)
  on.exit(try(p$kill(), silent = TRUE), add = TRUE)

  ps <- p$as_ps_handle()

  rm(p)
  gc()
  gc()

  deadline <- Sys.time() + 1
  while (ps::ps_is_running(ps) && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_false(ps::ps_is_running(ps))
})


test_that("run cleanup", {
  ## This currently only works on macOS
  if (Sys.info()[["sysname"]] != "Darwin") {
    expect_true(TRUE)
    return()
  }
  skip_on_cran()

  ## This is cumbesome to test... here is what we are doing.
  ## We run a grandchild process in the background, i.e. it will be
  ## orphaned. nohup will detach the process from the terminal, we
  ## need that, otherwise `run()` will wait for the shell to finish.
  ## We orphaned process writes its pid to a file, so we can read that
  ## back to see its process id.
  ## We also need to create a random file and run that, so that we
  ## can be sure that this process is not runing after the cleanup.
  ## Otherwise pid reuse might create the same pid, but then this pid
  ## will have a different command line.

  tmp <- tempfile()
  pid <- paste0(tmp, ".pid")
  btmp <- basename(tmp)
  bpid <- basename(pid)
  dtmp <- dirname(tmp)
  on.exit(unlink(c(tmp, pid)), add = TRUE)

  ## The sleep at the end gives a better chance for the grandchild
  ## process to write the pid before it is killed by the GC finalizer
  ## on the processx process.

  cat(sprintf("#! /bin/sh\necho $$ >%s\nsleep 10\n", bpid), file = tmp)
  Sys.chmod(tmp, "0777")
  run("sh",
      c("--norc", "-c",
        paste0("(nohup ", "./", btmp, " </dev/null &>/dev/null &); sleep 0.5")),
      wd = dtmp, cleanup_tree = TRUE)

  ## We need to wait until the process writes it pid into `pid`

  deadline <- Sys.time() + 3
  while ((!file.exists(pid) || !length(readLines(pid))) &&
         Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)

  ## Make sure the finalizer is called

  gc(); gc()

  ## Now either the pid should not exist, or, in the unlikely event
  ## when it does because of pid reuse, it should have a different command
  ## line.

  tryCatch({
    ps <- ps::ps_handle(as.integer(readLines(pid)))
    cmd <- ps::ps_cmdline(ps)
    expect_false(any(grepl(btmp, cmd))) },
    no_such_process = function(e) expect_true(TRUE)
  )
})

test_that("cleanup_tree stress test", {
  skip_on_cran()
  skip_if_no_ps()

  do <- function() {
    px <- get_tool("px")
    p <- process$new(px, c("sleep", "100"), cleanup_tree = TRUE)
    on.exit(try(p$kill(), silent = TRUE), add = TRUE)

    ps <- p$as_ps_handle()

    rm(p)
    gc()
    gc()

    deadline <- Sys.time() + 1
    while (ps::ps_is_running(ps) && Sys.time() < deadline) Sys.sleep(0.05)
    expect_true(Sys.time() < deadline)
    expect_false(ps::ps_is_running(ps))
  }

  for (i in 1:50) do()
})
