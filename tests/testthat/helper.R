
skip_other_platforms <- function(platform) {
  if (os_type() != platform) skip(paste("only run it on", platform))
}

skip_without_command <- function(command) {
  if (Sys.which(command) == "") {
    skip(paste("only run if", command, "is available"))
  }
}

try_silently <- function(expr) {
  tryCatch(
    expr,
    error = function(x) "error",
    warning = function(x) "warning",
    message = function(x) "message"
  )
}

sleep <- function(n, commandline = TRUE) {

  if (os_type() == "windows") {
    if (commandline) {
      paste("ping -n", n + 1L, "127.0.0.1 > NUL")
    } else {
      c("ping", "-n", as.character(n + 1L), "127.0.0.1")
    }

  } else {
    if (commandline) {
      paste("(sleep", n, ")")
    } else {
      c("sleep", as.character(n))
    }
  }
}
