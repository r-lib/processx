
os_type <- function() {
  .Platform$OS.type
}

is_windows <- function() {
  .Platform$OS.type == "windows"
}

is_osx <- function() {
  identical(Sys.info()[['sysname']], 'Darwin')
}

is_linux <- function() {
  identical(tolower(Sys.info()[["sysname"]]), "linux")
}

isFALSE <- function(x) {
  identical(FALSE, x)
}

`%||%` <- function(l, r) if (is.null(l)) r else l

last_char <- function(x) {
  nc <- nchar(x)
  substring(x, nc, nc)
}

# Given a filename, return an absolute path to that file. This has two important
# differences from normalizePath(). (1) The file does not need to exist, and (2)
# the path is merely absolute, whereas normalizePath() returns a canonical path,
# which resolves symbolic links, gives canonical case, and, on Windows, may give
# short names.
#
# On Windows, the returned path includes the drive ("C:") or network server
# ("//myserver"). Only "/" is supported as a path separator (no backslashes).
full_path <- function(path) {
  assert_that(is_string(path))

  # Try expanding "~"
  path <- path.expand(path)

  # If relative path, prepend current dir. On Windows, also record current
  # drive.
  if (is_windows()) {
    if (grepl("^[a-zA-Z]:", path)) {
      drive <- substring(path, 1, 2)
      path <- substring(path, 3)

    } else if (substring(path, 1, 2) == "//") {
      # Extract server name, like "//server", and use as drive.
      pos <- regexec("^(//[^/]*)(.*)", path)[[1]]
      drive <- substring(path, pos[2], attr(pos, "match.length", exact = TRUE)[2])
      path <- substring(path, pos[3])

      # Must have a name, like "//server"
      if (drive == "//")
        stop("Server name not found in network path.")

    } else {
      drive <- substring(getwd(), 1, 2)

      if (substr(path, 1, 1) != "/")
        path <- substring(file.path(getwd(), path), 3)
    }

  } else {
    if (substr(path, 1, 1) != "/")
      path <- file.path(getwd(), path)
  }

  parts <- strsplit(path, "/")[[1]]

  # Collapse any "..", ".", and "" in path.
  i <- 2
  while (i <= length(parts)) {
    if (parts[i] == "." || parts[i] == "") {
      parts <- parts[-i]

    } else if (parts[i] == "..") {
      if (i == 2) {
        parts <- parts[-i]
      } else {
        parts <- parts[-c(i-1, i)]
        i <- i-1
      }
    } else {
      i <- i+1
    }
  }

  new_path <- paste(parts, collapse = "/")
  if (new_path == "")
    new_path <- "/"

  if (is_windows())
    new_path <- paste0(drive, new_path)

  new_path
}
