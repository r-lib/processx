
context("environment")

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
})

test_that("specify custom env", {

  v <- basename(tempfile())
  if (os_type() == "unix") {
    cmd <- c("bash", "-c", paste0("echo $", v))
  } else {
    cmd <- c("cmd",  "/c", paste0("echo %", v, "%"))
  }

  skip_if_no_tool(cmd[1])

  out <- run(cmd[1], cmd[-1], env = structure("bar", names = v))
  expect_true(out$stdout %in% paste0("bar", c("\n", "\r\n")))
})
