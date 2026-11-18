test_that("supervisor tracks and kills supervised processes", {
  skip_on_cran()
  skip_on_os("windows")
  supervisor_reset()
  on.exit(supervisor_reset(), add = TRUE)

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "10"), supervise = TRUE)
  on.exit(p$kill(), add = TRUE)

  expect_true(supervisor_running())
  expect_true(p$is_supervised())

  p$supervise(FALSE)
  expect_false(p$is_supervised())
  p$supervise(FALSE)
  expect_false(p$is_supervised())
  p$supervise(TRUE)
  expect_true(p$is_supervised())

  # the supervisor kills its children when it gets the kill command
  supervisor_kill()
  expect_false(supervisor_running())
  p$wait(10000)
  expect_false(p$is_alive())
})

test_that("supervise() starts the supervisor if needed", {
  skip_on_cran()
  skip_on_os("windows")
  supervisor_reset()
  on.exit(supervisor_reset(), add = TRUE)

  px <- get_tool("px")
  p <- process$new(px, c("sleep", "10"))
  on.exit(p$kill(), add = TRUE)
  expect_false(supervisor_running())
  expect_false(p$is_supervised())

  p$supervise(TRUE)
  expect_true(supervisor_running())
  expect_true(p$is_supervised())

  # reset kills the running supervisor
  supervisor_reset()
  expect_false(supervisor_running())
  expect_null(supervisor_info$stdin)
})

test_that("supervisor_kill() is a no-op if the supervisor is not running", {
  supervisor_reset()
  expect_false(supervisor_running())
  expect_null(supervisor_kill())
})

test_that("supervisor_start() errors if the supervisor fails to start", {
  skip_on_cran()
  skip_on_os("windows")
  supervisor_reset()
  on.exit(supervisor_reset(), add = TRUE)

  # px does not understand the supervisor arguments and exits
  local_mocked_bindings(supervisor_path = function() get_tool("px"))
  expect_snapshot(error = TRUE, supervisor_start())
  expect_false(supervisor_running())
})

test_that("supervisor_path()", {
  path <- supervisor_path()
  expect_true(file.exists(path))
  expect_match(basename(path), "^supervisor")
})
