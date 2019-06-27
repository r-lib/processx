
context("client-lib")

test_that("client lib is standalone", {
  lib <- load_client_lib()
  on.exit(try(unload_client_lib(lib)), add = TRUE)

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
  lib <- load_client_lib()
  on.exit(try(unload_client_lib(lib)), add = TRUE)

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
  lib <- load_client_lib()
  on.exit(try(unload_client_lib(lib)), add = TRUE)

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
