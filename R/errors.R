
stop <- function(..., call. = TRUE, domain = NULL) {
  args <- list(...)

  if (length(args) == 1L && inherits(args[[1L]], "condition")) {
    if (nargs() > 1L) warning("additional arguments in stop()")
    cond <- args[[1L]]
    message <- conditionMessage(cond)
    call. <- conditionCall(cond)
    if (is.null(call.) || isTRUE(call.)) call. <- sys.call(-1)

  } else {
    message <- .makeMessage(..., domain = domain)
    if (is.null(call.) || isTRUE(call.)) call. <- sys.call(-1)
    cond <- structure(
      list(message = message, call = call.),
      class = c("simpleError", "error", "condition"))
  }

  signalCondition(cond)

  if (! "org:r-lib" %in% search()) {
    do.call("attach", list(new.env(), pos = length(search()),
                           name = "org:r-lib"))
  }
  env <- as.environment("org:r-lib")
  env$.Last.error <- cond

  class(cond) <- c("duplicate_condition", "condition")
  base::stop(cond)
}
