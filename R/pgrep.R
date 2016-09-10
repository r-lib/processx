
## pgrep does not include itself in the output, but on some systems
## (e.g. Linux) it does include its ancestors, which is a problem for us
## Here we make sure that ancestors are excluded on Linux

pgrep <- function(args) {
  if (is_linux()) {
    pgrep_linux(args)

  } else {
    pgrep_unix(args)
  }
}

pgrep_linux <- function(args) {
  print(safe_system("pgrep", "--version"))
  out <- safe_system("pgrep", c("-a", args))

  if (out$status > 0) {
    ## Some error, or no processes found, do not touch
    out

  } else {
    out$stdout <- strsplit(out$stdout, "\n", fixed = TRUE)[[1]]
    out$stdout <- grep(
      "^[0-9]+ sh -c 'pgrep'",
      out$stdout,
      value = TRUE,
      invert = TRUE
    )
    out$stdout <- sub("^([0-9]+).*$", "\\1", out$stdout, perl = TRUE)
    out$stdout <- paste(out$stdout, collapse = "\n")

    ## status denotes if there was a match
    if (out$stdout == "") out$status <- 1
    out
  }
}

pgrep_unix <- function(args) {
  safe_system("pgrep", args)
}
