test_that("print", {
  px <- get_tool("px")
  p <- process$new(px, c("sleep", "5"))
  on.exit(try_silently(p$kill(grace = 0)), add = TRUE)
  expect_output(
    print(p),
    "PROCESS .* running, pid"
  )

  p$kill()
  expect_output(
    print(p),
    "PROCESS .* finished"
  )
})

test_that("pipeline print", {
  skip_on_cran()
  px <- get_tool("px")

  pl <- pipeline$new(
    list(c(px, "cat", "<stdin>"), c(px, "cat", "<stdin>")),
    stdin = "|",
    stdout = "|"
  )
  on.exit(pl$kill(), add = TRUE)

  expect_output(print(pl), "^PIPELINE")
  expect_output(print(pl), "\\| .* running, pid")

  pl$close_input()
  pl$wait()
  expect_output(print(pl), "\\| .* finished")
})
