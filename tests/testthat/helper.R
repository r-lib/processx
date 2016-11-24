
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
  cmd <- paste0(
    "wmic process where (CommandLine Like '%", name, "%') ",
    "get CommandLine,ProcessId /format:list 2>&1"
  )

  wmic_out <- shell(cmd, intern = TRUE)
  parsed <- parse_wmic_list(wmic_out)

  ## To drop the wmic process itself
  parsed <- parsed[! grepl("wmic[ ]+process", parsed$CommandLine), ,
                   drop = FALSE]

  ## Just to be safe
  parsed <- parsed[grepl(name, parsed$CommandLine, fixed = TRUE), ,
                   drop = FALSE]

  if (nrow(parsed) == 0) {
    NULL
  } else {
    parsed$ProcessId[1]
  }
}

get_pid_by_name_unix <- function(name) {
  out <- safe_system("pgrep", c("-f", name))$stdout
  pid <- scan(text = out, quiet = TRUE)[1]
  if (is.na(pid)) NULL else pid
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

  ## All matching processes, including pgrep's ancestor shell(s)
  allproc <- str_trim(safe_system("pgrep", c("-d,", "-f", name))$stdout)

  ## List their full command lines
  out <- safe_system(
    "ps",
    c("-p", allproc, "--no-header", "-o", "pid=,command=")
  )$stdout

  ## Keep the ones that have 'name'
  out <- str_trim(strsplit(out, "\n", fixed = TRUE)[[1]])
  out <- grep(name, out, value = TRUE, fixed = TRUE)

  ## First field is process id
  first <- vapply(strsplit(out, " ", fixed = TRUE), "[[", "", 1L)
  pid <- scan(text = first, quiet = TRUE)[1]
  if (is.na(pid)) NULL else pid
}
