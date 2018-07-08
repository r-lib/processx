
context("kill_tree")

test_that("tree ids are inherited", {
  skip_on_cran()
  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"))
  on.exit(p$kill(), add = TRUE)
  ep <- ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)
  expect_equal(ps::ps_environ(ep)[[ev]], "YES")
})

test_that("tree ids are inherited if env is specified", {
  skip_on_cran()
  px <- get_tool("px")

  p <- process$new(px, c("sleep", "10"), env = c(FOO = "bar"))
  on.exit(p$kill(), add = TRUE)

  ep <-  ps::ps_handle(p$get_pid())

  ev <- paste0("PROCESSX_", get_private(p)$tree_id)
  expect_equal(ps::ps_environ(ep)[[ev]], "YES")
  expect_equal(ps::ps_environ(ep)[["FOO"]], "bar")
})
