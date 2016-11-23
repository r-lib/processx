
context("utils")

test_that("null_file", {

  ## We just want to make sure that null_file() is not an ordinary file

  ## system() does not allow redirect to NUL on windows
  exec <- if (os_type() == "windows") shell else system

  has <- file.exists(null_file())

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  withr::with_dir(
    tmp,
    {
      expect_silent(exec(paste0("echo nothing >", null_file())))
      expect_equal(has, file.exists(null_file()))
    }
  )
})

test_that("check_tool", {
  tool <-if (os_type() == "windows") "cmd" else "ls"
  expect_silent(check_tool(tool))
  expect_error(check_tool(basename(tempfile())), "Could not run")
})

test_that("wait_for_file", {

  ## Timing based tests are not allowed
  skip_on_cran()

  tmp <- tempfile()
  cmd <- paste0(sleep(1), " && (>", tmp, " echo hello)")
  p <- process$new(commandline = cmd, stdout = tmp)
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)

  expect_silent(wait_for_file(tmp, timeout = 3))
  expect_error(
    wait_for_file(tempfile(), timeout = 0.1),
    "File was not created"
  )
})

test_that("str_trim", {

  expect_equal(str_trim(""), "")
  expect_equal(str_trim("a"), "a")
  expect_equal(str_trim(" "), "")
  expect_equal(str_trim("a "), "a")
  expect_equal(str_trim(" a"), "a")
  expect_equal(str_trim(" a "), "a")

  expect_equal(str_trim(c("", "a")), c("", "a"))
  expect_equal(str_trim(c(" x", "a ")), c("x", "a"))
  expect_equal(str_trim(c(" x", " a")), c("x", "a"))
  expect_equal(str_trim(c(" x ", " a ")), c("x", "a"))
})
