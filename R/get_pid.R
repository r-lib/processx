
get_children <- function(pid) {
  if (os_type() == "windows") {
    get_children_windows(pid)
  } else {
    get_children_unix(pid)
  }
}

get_children_windows <- function(pid) {
  if (!length(pid)) return(integer())
  assert_pid(pid)
  pstab <- get_processes_windows(parent = pid)
  as.integer(pstab$ProcessId)
}

get_children_unix <- function(pid) {
  res <- pgrep(c("-P", pid))
  pid <- scan(text = res$stdout, what = 1, quiet = TRUE)
  pid
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

get_pid_tree <- function(pid) {
  children <- get_children(pid)
  c(unlist(lapply(children, get_pid_tree)), children)
}
