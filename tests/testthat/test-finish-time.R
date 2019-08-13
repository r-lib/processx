
context("finish_time")

test_that("finish_time works", {
  px <- get_tool("px")
  p <- process$new(px, c("sleep", "0.2"))
  on.exit(p$kill(), add = TRUE)
  expect_null(fin <- p$get_finish_time())
  p$wait(1)
  deadline <- Sys.time() + as.difftime(2, units = "secs")

  # It takes a bit of time for the SIGCHLD to arrive, so we need to
  # wait a bit here.
  while (Sys.time() < deadline && is.null(p$get_finish_time())) {
    Sys.sleep(0.05)
  }
  expect_false(is.null(p$get_finish_time()))
  expect_false(is.na(p$get_finish_time()))
  expect_true(p$get_finish_time() - p$get_start_time() < 0.5)

  p$kill()
  gc()
})
