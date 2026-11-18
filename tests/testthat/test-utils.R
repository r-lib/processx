test_that("full_path gives correct values", {
  skip_on_cran()

  if (is_windows()) {
    # Will be something like "C:"
    drive <- substring(getwd(), 1, 2)
  } else {
    # Use "" so that file.path("", "a") will return "/a"
    drive <- ""
  }

  expect_identical(full_path("/a/b"), file.path(drive, "a/b"))
  expect_identical(full_path("/a/b/"), file.path(drive, "a/b"))
  expect_identical(full_path("/"), file.path(drive, ""))
  expect_identical(full_path("a"), file.path(getwd(), "a"))
  expect_identical(full_path("a/b"), file.path(getwd(), "a/b"))

  expect_identical(full_path("a/../b/c"), file.path(getwd(), "b/c"))
  expect_identical(
    full_path(
      "../../../../../../../../../../../../../../../../../../../../../../../a"
    ),
    file.path(drive, "a")
  )
  expect_identical(full_path("/../.././a"), file.path(drive, "a"))
  expect_identical(full_path("/a/./b/../c"), file.path(drive, "a/c"))

  expect_identical(
    full_path("~nonexistent_user"),
    file.path(getwd(), "~nonexistent_user")
  )
  expect_identical(
    full_path("~/a/../b"),
    # On Windows, path.expand() can return a path with backslashes
    gsub("\\", "/", path.expand("~/b"), fixed = TRUE)
  )

  expect_identical(full_path("a//b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("/a//b"), file.path(drive, "a/b"))
})

test_that("full_path gives correct values, windows", {
  skip_other_platforms("windows")

  # Backslash separators
  expect_identical(full_path("f:\\a/b"), "f:/a/b")
  expect_identical(full_path("a\\b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("a\\\\b"), file.path(getwd(), "a/b"))
  expect_identical(full_path("\\\\a\\b"), "//a/b")
  expect_identical(full_path("\\\\a/b/..\\c"), "//a/c")

  # Drives
  expect_identical(full_path("f:/a/b"), "f:/a/b")
  expect_identical(full_path("f:/a/b/../../.."), "f:/")
  expect_identical(full_path("f:/../a"), "f:/a")
  expect_identical(full_path("f:/"), "f:/")
  expect_identical(full_path("f:"), "f:/")

  # Leading double slashes. Server name always has trailing slash ("//server/"),
  # like drives do ("f:/"). But dirs on the server don't have a trailing slash.
  expect_identical(full_path("//a"), "//a/")
  expect_identical(full_path("//a/"), "//a/")
  expect_identical(full_path("//a/b"), "//a/b")
  expect_identical(full_path("//a/b/.."), "//a/")
  # Can't go .. to remove the server name
  expect_identical(full_path("//a/b/../.."), "//a/")
  expect_identical(full_path("//a/../b"), "//a/b")
  expect_snapshot(error = TRUE, {
    full_path("//")
    full_path("///")
    full_path("///a")
  })
})

test_that("full_path gives correct values, unix", {
  skip_other_platforms("unix")

  # Leading double slashes should collapse
  expect_identical(full_path("//"), "/")
  expect_identical(full_path("///a/"), "/a")
})

test_that("do_echo_cmd", {
  skip_other_platforms("unix")

  expect_output(
    withr::with_options(
      list(width = 20),
      do_echo_cmd("command", rep("a r g x", 3))
    ),
    "Running command \\\n  'a r g x' \\\n  'a r g x' \\\n  'a r g x'",
    fixed = TRUE
  )
})

test_that("sh_quote_smart", {
  cases <- list(
    list(c("foo", "bar")),
    list(character()),
    list("foo"),
    list(""),
    list("foo/bar123_-"),

    list("foo bar", shQuote("foo bar")),
    list(c("foo", "1 2"), c("foo", shQuote("1 2")))
  )

  for (c in cases) {
    expect_equal(sh_quote_smart(c[[1]]), c[[length(c)]])
  }
})

test_that("write_raw_stdout writes bytes without text translation", {
  skip_on_cran()

  # Include bytes that text mode would mangle: \n (0x0a), \r (0x0d),
  # \r\n pairs, NUL (0x00), and high bytes (0x80, 0xff).
  bytes <- as.raw(c(0x00, 0x01, 0x0a, 0x0d, 0x0d, 0x0a, 0x80, 0xff))

  px <- get_tool("px")
  tf <- tempfile()
  on.exit(unlink(tf), add = TRUE)

  p <- process$new(px, c("rawout", "00010a0d0d0a80ff"), stdout = tf)
  p$wait()

  result <- readBin(tf, "raw", n = file.size(tf))
  expect_identical(result, bytes)
})

test_that("base64", {
  expect_equal(base64_encode(charToRaw("foobar")), "Zm9vYmFy")
  expect_equal(base64_encode(charToRaw(" ")), "IA==")
  expect_equal(base64_encode(charToRaw("")), "")

  x <- charToRaw(paste(sample(letters, 10000, replace = TRUE), collapse = ""))
  expect_equal(base64_decode(base64_encode(x)), x)

  for (i in 5:32) {
    mtcars2 <- unserialize(base64_decode(base64_encode(
      serialize(mtcars[1:i, ], NULL)
    )))
    expect_identical(mtcars[1:i, ], mtcars2)
  }
})

test_that("vcapply", {
  expect_equal(vcapply(1:3, as.character), c("1", "2", "3"))
  expect_equal(vcapply(character(), identity, USE.NAMES = FALSE), character())
})

test_that("strrep", {
  expect_equal(strrep(character(), 3), character())
  expect_equal(strrep("ab", 3), "ababab")
  expect_equal(strrep(c("a", "b"), c(1, 2)), c("a", "bb"))
  expect_equal(strrep(c("a", NA), 2), c("aa", NA))
  expect_equal(strrep("a", NA), NA_character_)
  expect_equal(strrep("a", 0), "")
})

test_that("starts_with", {
  expect_true(starts_with("foobar", "foo"))
  expect_false(starts_with("foobar", "bar"))
  expect_equal(starts_with(c("foo", "bar"), "fo"), c(TRUE, FALSE))
})

test_that("is_interactive", {
  # Only set these options while calling is_interactive(). Setting
  # `knitr.in.progress` while testthat runs its own code can make other
  # packages load knitr, which fails with a cyclic namespace error.
  with_opts <- function(...) {
    withr::with_options(list(...), is_interactive())
  }
  withr::local_options(
    rlib_interactive = NULL,
    knitr.in.progress = NULL,
    rstudio.notebook.executing = NULL
  )

  expect_true(with_opts(rlib_interactive = TRUE))
  expect_false(with_opts(rlib_interactive = FALSE))
  expect_false(with_opts(knitr.in.progress = TRUE))
  expect_false(with_opts(rstudio.notebook.executing = TRUE))

  withr::local_envvar(TESTTHAT = "true")
  expect_false(is_interactive())

  withr::local_envvar(TESTTHAT = NA)
  expect_equal(is_interactive(), interactive())
})

test_that("tty_echo_off(), tty_echo_on()", {
  skip_on_os("windows")
  skip_on_cran()
  if (isatty(stdout())) skip("stdout is a terminal")
  expect_error(tty_echo_off(), "Cannot turn terminal echo off")
  expect_error(tty_echo_on(), "Cannot turn terminal echo on")
})

test_that("disable_crash_dialog() in a subprocess", {
  skip_on_cran()
  res <- callr::r(function() {
    asNamespace("processx")$disable_crash_dialog()
    TRUE
  })
  expect_true(res)
})
