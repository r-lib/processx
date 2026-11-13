test_that("process is cleaned up", {
  px <- get_tool("px")
  p <- process$new(px, c("sleep", "1"), cleanup = TRUE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_false(process__exists(pid))
})

test_that("process can stay alive", {
  px <- get_tool("px")

  on.exit(tools::pskill(pid, 9), add = TRUE)
  p <- process$new(px, c("sleep", "60"), cleanup = FALSE)
  pid <- p$get_pid()

  rm(p)
  gc()

  expect_true(process__exists(pid))
})

test_that("GC cleanup kills the process group", {
  skip_on_os("windows")
  px <- get_tool("px")

  # The background child is in the same process group as `sh`, but
  # it is not in the process tree cleanup, because `cleanup_tree` is
  # FALSE. So only killing the process group can clean it up.
  p <- process$new(
    "sh",
    c("-c", paste(shQuote(px), "sleep 60 & echo $!; wait")),
    stdout = "|"
  )
  p$poll_io(5000)
  child <- as.integer(p$read_output_lines())
  on.exit(tools::pskill(child, tools::SIGKILL), add = TRUE)
  expect_true(process__exists(child))

  rm(p)
  gc()

  retry_until(function() !process__exists(child))
})

test_that("GC cleanup waits for the grace period", {
  skip_on_os("windows")
  px <- get_tool("px")

  p <- process$new(
    px,
    c("sigterm", "ignore", "outln", "ready", "sleep", "60"),
    stdout = "|",
    cleanup_grace = 0.5
  )
  p$poll_io(5000)
  expect_equal(p$read_output_lines(), "ready")
  pid <- p$get_pid()
  on.exit(tools::pskill(pid, tools::SIGKILL), add = TRUE)

  # Finalizers run right after gc() returns, so system.time(gc())
  # would not include them.
  start <- Sys.time()
  rm(p)
  gc()
  elapsed <- as.double(Sys.time() - start, units = "secs")

  # SIGTERM is ignored, so we need to wait the whole grace period
  expect_gte(elapsed, 0.4)
  retry_until(function() !process__exists(pid))
})

test_that("GC cleanup does not wait if the process exits on SIGTERM", {
  skip_on_os("windows")
  px <- get_tool("px")

  p <- process$new(px, c("sleep", "60"), cleanup_grace = 5)
  pid <- p$get_pid()
  on.exit(tools::pskill(pid, tools::SIGKILL), add = TRUE)

  # Finalizers run right after gc() returns, so system.time(gc())
  # would not include them.
  start <- Sys.time()
  rm(p)
  gc()
  elapsed <- as.double(Sys.time() - start, units = "secs")

  expect_lt(elapsed, 2)
  retry_until(function() !process__exists(pid))
})

test_that("session quit kills processes in parallel", {
  skip_on_os("windows")
  skip_on_cran()
  skip_if_not_installed("callr")
  px <- get_tool("px")

  rp <- callr::r_bg(
    function(px) {
      ps <- lapply(1:3, function(i) {
        processx::process$new(
          px,
          c("sigterm", "ignore", "outln", "ready", "sleep", "60"),
          stdout = "|",
          cleanup_grace = 1
        )
      })
      for (p in ps) p$poll_io(5000)
      keep <- processx::process$new(px, c("sleep", "60"), cleanup = FALSE)
      # Keep them alive until the session quits
      assign(".processes", c(ps, list(keep)), envir = globalenv())
      cat(sapply(ps, function(p) p$get_pid()), sep = "\n")
      cat(keep$get_pid(), "\n", sep = "")
      invisible()
    },
    list(px = px),
    stdout = "|"
  )
  on.exit(rp$kill(), add = TRUE)

  pids <- character()
  deadline <- Sys.time() + 10
  while (length(pids) < 4 && Sys.time() < deadline) {
    rp$poll_io(1000)
    pids <- c(pids, rp$read_output_lines())
  }
  pids <- as.integer(pids)
  expect_length(pids, 4)
  killed <- pids[1:3]
  kept <- pids[4]
  on.exit(tools::pskill(pids, tools::SIGKILL), add = TRUE)

  # The three processes ignore SIGTERM and have a 1s grace period.
  # Killed one by one this would take 3s, in parallel about 1s.
  start <- Sys.time()
  rp$wait(10000)
  elapsed <- as.double(Sys.time() - start, units = "secs")
  expect_false(rp$is_alive())
  expect_lt(elapsed, 2.5)

  retry_until(function() !any(sapply(killed, process__exists)))
  expect_true(process__exists(kept))
})
