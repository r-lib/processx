
test_that("UTF-8 executable name", {
  skip_on_cran()
  local_temp_dir()
  name <- "./\u00fa\u00e1\u00f6\u0151\u00e9.exe"
  px <- get_tool("px")
  file.copy(px, name)
  out <- run(
    name,
    c("out", "hello", "return", 10),
    error_on_status = FALSE
  )
  expect_equal(out$stdout, "hello")
  expect_equal(out$status, 10)
})

test_that("UTF-8 directory name", {
  skip_on_cran()
  local_temp_dir()
  name <- "./\u00fa\u00e1\u00f6\u0151\u00e9.exe"
  # Older dir.create does not handle UTF-8 correctly
  if (getRversion() < "4.0.0") {
    dir.create(enc2native(name))
  } else {
    dir.create(name)
  }
  px <- get_tool("px")
  exe <- file.path(name, "px.exe")
  if (getRversion() < "4.0.0") {
    file.copy(px, enc2native(exe))
  } else {
    file.copy(px, exe)
  }
  out <- run(
    exe,
    c("out", "hello", "return", 10),
    error_on_status = FALSE
  )
  expect_equal(out$stdout, "hello")
  expect_equal(out$status, 10)
})

test_that("UTF-8 argument", {
  skip_other_platforms("windows")
  local_temp_dir()
  unc <- "\u00fa\u00e1\u00f6\u0151\u00e9\u0414\u041e\u0411\u0420\u041e"
  out <- run(get_tool("pxu"), c("writefile", "of", unc))
  outarg <- readBin("of", what = "raw", n = 200)
  exp <- iconv(unc, from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1]]
  expect_equal(exp, outarg)
})

test_that("native program name is converted to UTF-8", {
  skip_other_platforms("windows")
  if (!l10n_info()$`Latin-1`) skip("Needs latin1 locale")
  local_temp_dir()
  exe <- enc2native("./\u00fa\u00e1\u00f6.exe")
  file.copy(get_tool("px"), exe)
  out <- run(exe, c("return", 10), error_on_status = FALSE)
  expect_equal(out$status, 10)
})

test_that("native args are converted to UTF-8", {
  skip_other_platforms("windows")
  if (!l10n_info()$`Latin-1`) skip("Needs latin1 locale")
  local_temp_dir()
  name <- enc2native("\u00fa\u00e1\u00f6")

  out <- run(get_tool("px"), c("writefile", "of", name))
  expect_equal(
    charToRaw(name),
    readBin("of", what = "raw", n = 100)
  )

  out2 <- run(get_tool("pxu"), c("writefile", "of2", name))
  expect_equal(
    iconv(name, to = "UTF-16LE", toRaw = TRUE)[[1]],
    readBin("of2", what = "raw", n = 100)
  )
})

# TODO: more UTF-8 output

test_that("UTF-8 in stdout", {
  skip_on_cran()
  # "px" is not unicode on Windows, so we need to specify encoding = "latin1"
  enc <- if (is_windows()) "latin1" else ""
  out <- run(get_tool("px"), c("out", "\u00fa\u00e1\u00f6"), encoding = enc)
  expect_equal(out$stdout, "\u00fa\u00e1\u00f6")
})

test_that("UTF-8 in stderr", {
  skip_on_cran()
  # "px" is not unicode on Windows, so we need to specify encoding = "latin1"
  enc <- if (is_windows()) "latin1" else ""
  out <- run(get_tool("px"), c("err", "\u00fa\u00e1\u00f6"), encoding = enc)
  expect_equal(out$stderr, "\u00fa\u00e1\u00f6")
})
