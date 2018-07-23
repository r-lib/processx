
context("kill_tree")

test_that("tree ids are inherited", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"))
  on.exit(p$kill(), add = TRUE)
  ep <- ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)
  expect_equal(ps::ps_environ(ep)[[ev]], "YES")
})

test_that("tree ids are inherited if env is specified", {
  skip_on_cran()
  skip_if_no_ps()

  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"), env = c(FOO = "bar"))
  on.exit(p$kill(), add = TRUE)

  ep <-  ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)
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

  ps <- ps::ps_handle(pres$pid, pres$create_time)
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