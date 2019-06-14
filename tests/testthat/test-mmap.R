
context("mmap")

test_that("mmap for myself", {
  skip_other_platforms("unix")

  data <- list(
    1:100, runif(100000), charToRaw("foobar"), 1:100 < sample(1:100))

  map <- .Call(c_processx__mmap_pack, tempfile(), data)

  ret <- .Call(c_processx__mmap_unpack, map[[1]])

  expect_identical(data, ret)
})

test_that("mmap to subprocess", {
  skip_other_platforms("unix")

  data <- list(
    1:100, runif(100000), charToRaw("foobar"), 1:100 < sample(1:100))
  map <- conn_create_mmap(data)
  on.exit(close(map), add = TRUE)

  proc <- callr::r_bg(
    function() {
      .Call(asNamespace("processx")$c_processx__mmap_unpack, 3L)
    },
    poll_connection = FALSE,
    connections = list(map))
  on.exit(proc$kill(), add = TRUE)
  proc$wait(1000)

  ret <- proc$get_result()
  expect_identical(data, ret)
})
