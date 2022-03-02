
test_that("inherit by default", {

  v <- basename(tempfile())
  if (os_type() == "unix") {
    cmd <- c("bash", "-c", paste0("echo $", v))
  } else {
    cmd <- c("cmd",  "/c", paste0("echo %", v, "%"))
  }

  skip_if_no_tool(cmd[1])

  out <- run(cmd[1], cmd[-1])
  expect_true(out$stdout %in% c("\n", paste0("%", v, "%\r\n")))
  gc()
})

test_that("specify custom env", {

  v <- c(basename(tempfile()), basename(tempfile()))
  if (os_type() == "unix") {
    cmd <- c("bash", "-c", paste0("echo ", paste0("$", v, collapse = " ")))
  } else {
    cmd <- c("cmd",  "/c", paste0("echo ", paste0("%", v, "%", collapse = " ")))
  }

  skip_if_no_tool(cmd[1])

  out <- run(cmd[1], cmd[-1], env = structure(c("bar", "baz"), names = v))
  expect_true(out$stdout %in% paste0("bar baz", c("\n", "\r\n")))
  gc()
})

test_that("append to env", {
  withr::local_envvar(FOO = "fooe", BAR = "bare")
  px <- get_tool("px")
  out <- run(
    px,
    c("getenv", "FOO", "getenv", "BAR", "getenv", "BAZ"),
    env = c("current", BAZ = "baze", BAR = "bare2")
  )

  outenv <- strsplit(out$stdout, "\r?\n")[[1]]
  expect_equal(outenv, c("fooe", "bare2", "baze"))
})
