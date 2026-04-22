test_that("2-process pipeline: sort | uniq", {
  skip_on_cran()

  pl <- pipeline$new(
    list(c("sort"), c("uniq")),
    stdin = "|",
    stdout = "|"
  )
  on.exit(pl$kill(), add = TRUE)

  pl$write_input("b\na\nb\na\n")
  pl$close_input()
  out <- pl$read_all_output_lines()
  pl$wait()

  expect_equal(out, c("a", "b"))
  expect_equal(pl$get_exit_statuses(), list(0L, 0L))
})

test_that("3-process pipeline: cat | sort | uniq", {
  skip_on_cran()

  pl <- pipeline$new(
    list(c("cat"), c("sort"), c("uniq")),
    stdin = "|",
    stdout = "|"
  )
  on.exit(pl$kill(), add = TRUE)

  pl$write_input("b\na\nb\na\n")
  pl$close_input()
  out <- pl$read_all_output_lines()
  pl$wait()

  expect_equal(out, c("a", "b"))
  expect_equal(pl$get_exit_statuses(), list(0L, 0L, 0L))
})

test_that("single-process pipeline is equivalent to process$new()", {
  skip_on_cran()

  pl <- pipeline$new(list(c("echo", "hello")), stdout = "|")
  on.exit(pl$kill(), add = TRUE)

  pl$wait()
  out <- trimws(pl$read_all_output())
  expect_equal(out, "hello")
  expect_equal(pl$get_exit_statuses(), list(0L))
})

test_that("pipeline is_alive() and get_pids()", {
  skip_on_cran()

  pl <- pipeline$new(
    list(c("sort"), c("cat")),
    stdin = "|",
    stdout = "|"
  )
  on.exit(pl$kill(), add = TRUE)

  expect_true(pl$is_alive())
  pids <- pl$get_pids()
  expect_length(pids, 2L)
  expect_true(all(pids > 0L))

  pl$close_input()
  pl$wait()
  expect_false(pl$is_alive())
})

test_that("pipeline get_processes() returns process objects", {
  skip_on_cran()

  pl <- pipeline$new(
    list(c("sort"), c("uniq")),
    stdin = "|",
    stdout = "|"
  )
  on.exit(pl$kill(), add = TRUE)

  procs <- pl$get_processes()
  expect_length(procs, 2L)
  expect_true(all(vapply(procs, inherits, logical(1L), "process")))

  pl$close_input()
  pl$wait()
})

test_that("pipeline kill() stops all processes", {
  skip_on_cran()

  pl <- pipeline$new(
    list(c("cat"), c("cat")),
    stdin = "|",
    stdout = "|"
  )

  expect_true(pl$is_alive())
  pl$kill()
  Sys.sleep(0.1)
  expect_false(pl$is_alive())
})

test_that("pipeline stdout to file", {
  skip_on_cran()

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)

  pl <- pipeline$new(
    list(c("sort"), c("uniq")),
    stdin = "|",
    stdout = tmp
  )
  on.exit(pl$kill(), add = TRUE)

  pl$write_input("b\na\nb\na\n")
  pl$close_input()
  pl$wait()

  expect_equal(readLines(tmp), c("a", "b"))
  expect_equal(pl$get_exit_statuses(), list(0L, 0L))
})

test_that("conn_create_proc_pipepair() returns write/read ends", {
  skip_on_cran()

  pipe <- conn_create_proc_pipepair()
  on.exit({
    try(close(pipe[[1]]), silent = TRUE)
    try(close(pipe[[2]]), silent = TRUE)
  }, add = TRUE)

  expect_length(pipe, 2L)
  expect_true(is_connection(pipe[[1]]))
  expect_true(is_connection(pipe[[2]]))
})
