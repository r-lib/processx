
context("ps methods")

test_that("ps methods", {
  skip_if_no_ps()

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "100"))
  on.exit(p$kill(), add = TRUE)

  ps <- p$as_ps_handle()
  expect_s3_class(ps, "ps_handle")
  expect_true(ps::ps_name(ps) %in% c("px", "px.exe"))

  expect_equal(p$get_name(), ps::ps_name(ps))
  expect_equal(p$get_exe(), ps::ps_exe(ps))
  expect_equal(p$get_cmdline(), ps::ps_cmdline(ps))
  expect_equal(p$get_status(), ps::ps_status(ps))
  expect_equal(p$get_username(), ps::ps_username(ps))
  expect_equal(p$get_wd(), ps::ps_cwd(ps))
  expect_equal(names(p$get_cpu_times()), names(ps::ps_cpu_times(ps)))
  expect_equal(names(p$get_memory_info()), names(ps::ps_memory_info(ps)))

  p$suspend()
  deadline <- Sys.time() + 3
  while (p$get_status() != "stopped" && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_equal(p$get_status(), "stopped")

  p$resume()
  deadline <- Sys.time() + 3
  while (p$get_status() == "stopped" && Sys.time() < deadline) Sys.sleep(0.05)
  expect_true(Sys.time() < deadline)
  expect_true(p$get_status() != "stopped")
})
