
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

get_wintool <- function(prog) {
  exe <- system.file(package = "processx", "bin", .Platform$r_arch, prog)
  if (exe == "") {
    pkgpath <- system.file(package = "processx")
    if (basename(pkgpath) == "inst") pkgpath <- dirname(pkgpath)
    exe <- file.path(pkgpath, "src", "tools", prog)
    if (!file.exists(exe)) return("")
  }
  exe
}

sleep <- function(n) {

  commandline <- FALSE

  if (os_type() == "windows") {
    sleepexe <- get_wintool("sleep.exe")
    if (sleepexe == "") skip("Cannot run sleep.exe")
    if (commandline) {
      paste(sleepexe, n)
    } else {
      c(sleepexe, as.character(n))
    }

  } else {
    if (commandline) {
      paste("(sleep", n, ")")
    } else {
      c("sleep", as.character(n))
    }
  }
}

## type is not good, because it needs cmd
## more is another candidate, but it does not handle long lines, it cuts them
## so we go with cat

cat_command <- function() {
  if (os_type() == "windows") "cat" else "cat"
}

skip_if_no_command <- function(command) {
  if (Sys.which(command) == "") skip(paste0("No '", command, "' command"))
}

skip_if_no_cat <- function() {
  cat <- cat_command()
  skip_if_no_command(cat)
}

get_pid_by_name <- function(name) {
  if (os_type() == "windows") {
    get_pid_by_name_windows(name)
  } else if (is_linux()) {
    get_pid_by_name_linux(name)
  } else {
    get_pid_by_name_unix(name)
  }
}

get_pid_by_name_windows <- function(name) {
  ## TODO
}

## Linux does not exclude the ancestors of the pgrep process
## from the list, so we have to do that manually. We remove every
## process that contains 'pgrep' in its command line, which is
## not the proper solution, but for testing it will do.
##
## Unfortunately Ubuntu 12.04 pgrep does not have a -a switch,
## so we cannot just output the full command line and then filter
## it in R. So we first run pgrep to get all matching process ids
## (without their command lines), and then use ps to list the processes
## again. At this time the first pgrep process is not running any
## more, but another process might have its id, so we filter again the
## result for 'name'

get_pid_by_name_linux <- function(name) {
  ## TODO
}
