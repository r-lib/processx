test_that("curl fds", {
  skip_on_cran()

  resp <- list()
  errm <- character()
  done <- function(x) resp <<- c(resp, list(x))
  fail <- function(x) errm <<- c(errm, x)

  pool <- curl::new_pool()
  url1 <- httpbin$url("/status/200")
  url2 <- httpbin$url("/delay/1")
  curl::multi_add(
    pool = pool,
    curl::new_handle(url = url1),
    done = done,
    fail = fail
  )
  curl::multi_add(
    pool = pool,
    curl::new_handle(url = url1),
    done = done,
    fail = fail
  )
  curl::multi_add(
    pool = pool,
    curl::new_handle(url = url2),
    done = done,
    fail = fail
  )
  curl::multi_add(
    pool = pool,
    curl::new_handle(url = url1),
    done = done,
    fail = fail
  )
  curl::multi_add(
    pool = pool,
    curl::new_handle(url = url1),
    done = done,
    fail = fail
  )

  # This does not do much, but at least it tests that we can poll()
  # libcurl's file descriptors

  timeout <- Sys.time() + 5
  repeat {
    fds <- curl::multi_fdset(pool = pool)
    if (length(fds$reads) > 0) {
      pr <- poll(list(curl_fds(fds)), 1000)
    }
    state <- curl::multi_run(timeout = 0.1, pool = pool, poll = TRUE)
    if (state$pending == 0 || Sys.time() >= timeout) break
  }

  expect_true(Sys.time() < timeout)
  expect_equal(vapply(resp, "[[", "", "url"), c(rep(url1, 4), url2))
})

test_that("curl fds before others", {
  skip_on_cran()

  pool <- curl::new_pool()
  url <- httpbin$url("/delay/1")
  curl::multi_add(pool = pool, curl::new_handle(url = url))

  timeout <- Sys.time() + 5
  repeat {
    state <- curl::multi_run(timeout = 1 / 10000, pool = pool, poll = TRUE)
    fds <- curl::multi_fdset(pool = pool)
    if (length(fds$reads) > 0) {
      break
    }
    if (Sys.time() >= timeout) break
  }

  expect_true(Sys.time() < timeout)

  px <- get_tool("px")
  pp <- process$new(get_tool("px"), c("sleep", "10"))
  on.exit(pp$kill(), add = TRUE)

  pr <- poll(list(pp, curl_fds(fds)), 10000)
  expect_equal(
    pr,
    list(c(output = "nopipe", error = "nopipe", process = "silent"), "event")
  )

  pp$kill()
})

test_that("process fd before curl fd", {
  skip_on_cran()

  pool <- curl::new_pool()
  url <- httpbin$url("/delay/10")
  # The /delay endpoint sends the response headers right away, and then
  # it waits before sending the body. We need to wait until curl has
  # read the headers, otherwise they might arrive during the poll()
  # below and the curl fd would have an event.
  got_headers <- FALSE
  handle <- curl::new_handle(url = url)
  curl::handle_setopt(
    handle,
    verbose = TRUE,
    debugfunction = function(type, data) {
      # type 1 is an incoming header line, an empty line ends the headers
      if (type == 1 && identical(data, as.raw(c(0x0d, 0x0a)))) {
        got_headers <<- TRUE
      }
    }
  )
  curl::multi_add(pool = pool, handle)

  timeout <- Sys.time() + 5
  repeat {
    state <- curl::multi_run(timeout = 1 / 10000, pool = pool, poll = TRUE)
    fds <- curl::multi_fdset(pool = pool)
    if (got_headers && length(fds$reads) > 0 && length(fds$writes) == 0) {
      break
    }
    if (Sys.time() >= timeout) break
  }

  expect_true(Sys.time() < timeout)

  px <- get_tool("px")
  pp <- process$new(get_tool("px"), c("outln", "done"))
  on.exit(pp$kill(), add = TRUE)

  pr <- poll(list(pp, curl_fds(fds)), 10000)
  expect_equal(
    pr,
    list(c(output = "nopipe", error = "nopipe", process = "ready"), "silent")
  )

  pp$kill()
})
