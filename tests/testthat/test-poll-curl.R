
## To resolve....
online <- curl::has_internet()
if (online) httpbin()

test_that("curl fds", {
  skip_on_cran()
  if (!online) skip("Offline")

  resp <- list()
  errm <- character()
  done <- function(x) resp <<- c(resp, list(x))
  fail <- function(x) errm <<- c(errm, x)

  pool <- curl::new_pool()
  url1 <- httpbin("/status/200")
  url2 <- httpbin("/delay/1")
  curl::multi_add(pool = pool, curl::new_handle(url = url1),
                  done = done, fail = fail)
  curl::multi_add(pool = pool, curl::new_handle(url = url1),
                  done = done, fail = fail)
  curl::multi_add(pool = pool, curl::new_handle(url = url2),
                  done = done, fail = fail)
  curl::multi_add(pool = pool, curl::new_handle(url = url1),
                  done = done, fail = fail)
  curl::multi_add(pool = pool, curl::new_handle(url = url1),
                  done = done, fail = fail)

  timeout <- Sys.time() + 5
  repeat {
    state <- curl::multi_run(timeout = 1/10000, pool = pool, poll = TRUE)
    fds <- curl::multi_fdset(pool = pool)
    if (length(fds$reads) > 0) break;
    if (Sys.time() >= timeout) break;
  }

  expect_true(Sys.time() < timeout)

  xfds <- list()
  xpr <- character()

  while (state$pending > 0) {
    fds <- curl::multi_fdset(pool = pool)
    xfds <- c(xfds, fds["reads"])
    pr <- poll(list(curl_fds(fds)), 2000)
    xpr <- c(xpr, pr[[1]])
    state <- curl::multi_run(timeout = 0.1, pool = pool, poll = TRUE)
  }

  expect_true(all(vapply(xfds, length, 1L) > 0))
  expect_true(all(xpr == "event"))

  expect_equal(vapply(resp, "[[", "", "url"), c(rep(url1, 4), url2))
})

test_that("curl fds before others", {
  skip_on_cran()
  if (!online) skip("Offline")

  pool <- curl::new_pool()
  url <- httpbin("/delay/1")
  curl::multi_add(pool = pool, curl::new_handle(url = url))

  timeout <- Sys.time() + 5
  repeat {
    state <- curl::multi_run(timeout = 1/10000, pool = pool, poll = TRUE)
    fds <- curl::multi_fdset(pool = pool)
    if (length(fds$reads) > 0) break;
    if (Sys.time() >= timeout) break;
  }

  expect_true(Sys.time() < timeout)

  px <- get_tool("px")
  pp <- process$new(get_tool("px"), c("sleep", "10"))
  on.exit(pp$kill(), add = TRUE)

  pr <- poll(list(pp, curl_fds(fds)), 10000)
  expect_equal(
    pr,
    list(c(output = "nopipe", error = "nopipe", process = "silent"),
         "event")
  )

  pp$kill()
})

test_that("process fd before curl fd", {
  skip_on_cran()
  if (!online) skip("Offline")

  pool <- curl::new_pool()
  url <- httpbin("/delay/1")
  curl::multi_add(pool = pool, curl::new_handle(url = url))

  timeout <- Sys.time() + 5
  repeat {
    state <- curl::multi_run(timeout = 1/10000, pool = pool, poll = TRUE)
    fds <- curl::multi_fdset(pool = pool)
    if (length(fds$reads) > 0) break;
    if (Sys.time() >= timeout) break;
  }

  expect_true(Sys.time() < timeout)

  px <- get_tool("px")
  pp <- process$new(get_tool("px"), c("outln", "done"))
  on.exit(pp$kill(), add = TRUE)

  pr <- poll(list(pp, curl_fds(fds)), 10000)
  expect_equal(
    pr,
    list(c(output = "nopipe", error = "nopipe", process = "ready"),
         "silent")
  )

  pp$kill()
})
