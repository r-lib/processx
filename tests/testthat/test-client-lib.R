
test_that("client lib is standalone", {
  lib <- load_client_lib(client)
  on.exit(try(lib$.finalize()), add = TRUE)

  objs <- ls(lib, all.names = TRUE)
  funs <- Filter(function(x) is.function(lib[[x]]), objs)
  funobjs <- mget(funs, lib)
  for (f in funobjs) expect_identical(environmentName(topenv(f)), "base")

  expect_message(
    mapply(codetools::checkUsage, funobjs, funs,
           MoreArgs = list(report = message)),
    NA)
})

test_that("base64", {
  lib <- load_client_lib(client)
  on.exit(try(lib$.finalize()), add = TRUE)

  expect_equal(lib$base64_encode(charToRaw("foobar")), "Zm9vYmFy")
  expect_equal(lib$base64_encode(charToRaw(" ")), "IA==")
  expect_equal(lib$base64_encode(charToRaw("")), "")

  x <- charToRaw(paste(sample(letters, 10000, replace = TRUE), collapse = ""))
  expect_equal(lib$base64_decode(lib$base64_encode(x)), x)

  for (i in 5:32) {
    mtcars2 <- unserialize(lib$base64_decode(lib$base64_encode(
      serialize(mtcars[1:i, ], NULL))))
    expect_identical(mtcars[1:i,], mtcars2)
  }
})

test_that("disable_inheritance", {
  ## TODO
  expect_true(TRUE)
})

test_that("write_fd", {
  lib <- load_client_lib(client)
  on.exit(try(lib$.finalize()), add = TRUE)

  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)

  conn <- conn_create_file(tmp, read = FALSE, write = TRUE)
  fd <- conn_get_fileno(conn)

  obj <- runif(100000)
  data <- serialize(obj, connection = NULL)
  lib$write_fd(fd, data)
  close(conn)

  expect_identical(readRDS(tmp), obj)
})

test_that("processx_connection_set_stdout", {
  stdout_to_file <- function(filename) {
    lib <- asNamespace("processx")$load_client_lib(processx:::client)
    lib$set_stdout_file(filename)
    cat("output\n")
    message("error")
    42
  }

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  opt <- callr::r_process_options(
    func = stdout_to_file,
    args = list(filename = tmp))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill(close_connections = FALSE))
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_error_lines(), "error")
  expect_equal(p$read_all_output_lines(), character())
  expect_equal(readLines(tmp), "output")
  p$kill()
})

test_that("processx_connection_set_stdout", {
  stderr_to_file <- function(filename) {
    lib <- asNamespace("processx")$load_client_lib(processx:::client)
    lib$set_stderr_file(filename)
    cat("output\n")
    message("error")
    42
  }

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  opt <- callr::r_process_options(
    func = stderr_to_file,
    args = list(filename = tmp))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill(close_connections = FALSE))
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_output_lines(), "output")
  expect_equal(p$read_all_error_lines(), character())
  expect_equal(readLines(tmp), "error")
  p$kill()
})

test_that("setting stdout multiple times", {
  stdout_to_file <- function(file1, file2) {
    lib <- asNamespace("processx")$load_client_lib(processx:::client)
    lib$set_stdout_file(file1)
    cat("output\n")
    message("error")

    lib$set_stdout_file(file2)
    cat("output2\n")
    message("error2")

    42
  }

  tmp1 <- tempfile()
  tmp2 <- tempfile()
  on.exit(unlink(c(tmp1, tmp2)), add = TRUE)
  opt <- callr::r_process_options(
    func = stdout_to_file,
    args = list(file1 = tmp1, file2 = tmp2))
  on.exit(p$kill(), add = TRUE)
  p <- callr::r_process$new(opt)

  p$wait(5000)
  expect_false(p$kill(close_connections = FALSE))
  expect_equal(p$get_result(), 42)
  expect_equal(p$read_all_error_lines(), c("error", "error2"))
  expect_equal(p$read_all_output_lines(), character())
  expect_equal(readLines(tmp1), "output")
  expect_equal(readLines(tmp2), "output2")
  p$kill()
})
