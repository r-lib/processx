
get_children <- function(pid) {
  if (!length(pid)) return(integer())
  assert_pid(pid)
  pstab <- get_processes_windows(parent = pid)
  as.integer(pstab$ProcessId)
}

get_processes_windows <- function(parent) {
  check_tool("wmic")

  ## Do we search among children, or in general?
  cmd <- if (!is.null(parent)) {
    paste0(
      "wmic process where (ParentProcessID=", parent, ") ",
      "get Caption,CommandLine,ProcessId /format:list ",
      "2>&1"
    )
  } else {
    "wmic process get Caption,CommandLine,ProcessId /format:list 2>&1"
  }

  wmic_out <- shell(cmd, intern = TRUE)
  parse_wmic_list(wmic_out)
}

parse_wmic_list <- function(text) {
  text <- paste(text, collapse = "\n")
  text <- win2unix(text)

  ## No processes in list
  if (grepl("^No Instance", text[1])) {
    return(data.frame(
      stringsAsFactors = FALSE,
      Caption = character(),
      CommandLine = character(),
      ProcessId = character()
    ))
  }

  ## Records are separated by empty lines
  records <- strsplit(text, "\n\n+")[[1]]

  ## Drop empty lines
  records <- grep("^\\s*$", records, value = TRUE, invert = TRUE)

  ## Break into fields
  ## Fields are in the key=value format
  fields <- strsplit(records, "\n")
  keys <- lapply(fields, sub, pattern = "=.*$", replacement = "")
  vals <- lapply(fields, sub, pattern = "^[^=]+=", replacement = "")

  structure(
    do.call(rbind.data.frame, c(vals, list(stringsAsFactors = FALSE))),
    names = keys[[1]]
  )
}

get_pid_by_name <- function(name, children = TRUE) {
  if (os_type() == "windows") {
    get_pid_by_name_windows(name, children)
  } else {
    get_pid_by_name_unix(name, children)
  }
}

get_pid_by_name_windows <- function(name, children) {

  pstab <- get_processes_windows(
    if (children) Sys.getpid() else NULL
  )

  pids <- pstab$ProcessId[grepl(name, pstab$CommandLine, fixed = TRUE)]

  if (length(pids) >= 1) pids else NULL
}

#' @importFrom utils tail

get_pid_by_name_unix <- function(name, children) {

  ## NOTE: 'children' is ignored on unix, because the started
  ## process might not be a child of the R process, anyway.

  res <- safe_system("pgrep", c("-f", name))

  ## This is the same on macOS, Solaris & Linux \o/
  ## 0   One or more processes matched
  ## 1   No processes matched
  ## 2   Syntax error in the command line
  ## 3   Internal error
  if (res$status > 1) {
    stop("Could not run 'pgrep'. 'process' needs 'pgrep' on this platform")
  }

  pid <- scan(text = res$stdout, what = 1, quiet = TRUE)

  ## Looks like system2() sometimes starts two shells, i.e. the first
  ## starts the second, with the same command line. We just take the
  ## last process in this case.

  if (length(pid) >= 1) {
    tail(sort(pid), 1)
  } else if (length(pid) == 0) {
    NULL
  }
}
