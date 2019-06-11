
err <- local({

  trace_back <- function() {
    idx <- seq_len(sys.parent(1L))
    frames <- sys.frames()[idx]
    parents <- sys.parents()[idx]
    calls <- as.list(sys.calls()[idx])
    envs <- lapply(frames, env_label)
    trace <- new_trace(calls, parents, envs)
    trace
  }

  new_trace <- function (calls, parents, envs) {
    indices <- seq_along(calls)
    structure(
      list(calls = calls, parents = parents, envs = envs,
           indices = indices),
      class = "rlib_trace")
  }

  env_label <- function(env) {
    nm <- env_name(env)
    if (nzchar(nm)) {
      nm
    } else {
      env_address(env)
    }
  }

  env_address <- function(env) {
    class(env) <- "environment"
    sub("^.*(0x[0-9a-f]+)>$", "\\1", format(env), perl = TRUE)
  }

  env_name <- function(env) {
    if (identical(env, globalenv())) {
      return("global")
    }
    if (identical(env, baseenv())) {
      return("package:base")
    }
    if (identical(env, emptyenv())) {
      return("empty")
    }
    nm <- environmentName(env)
    if (isNamespace(env)) {
      return(paste0("namespace:", nm))
    }
    nm
  }

  print_rlib_error <- function(x, ...) {
    ## TODO: better printing
    NextMethod("print")
    invisible(x)
  }

  print_rlib_trace <- function(x, ...) {
    ## TODO: better printing
    print(x$calls)
    invisible(x)
  }

  throw <- function(..., call. = TRUE, domain = NULL) {
    args <- list(...)

    if (length(args) == 1L && inherits(args[[1L]], "condition")) {
      if (nargs() > 1L) warning("additional arguments in throw()")
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

    class(cond) <- c(
      setdiff(class(cond), c("simpleError", "error", "condition")),
      "rlib_error", "error", "condition")
    signalCondition(cond)

    if (! "org:r-lib" %in% search()) {
      do.call("attach", list(new.env(), pos = length(search()),
                             name = "org:r-lib"))
    }
    env <- as.environment("org:r-lib")
    env$print.rlib_error <- print_rlib_error
    env$print.rlib_trace <- print_rlib_trace

    cond$trace <- trace_back()
    env$.Last.error <- cond

    class(cond) <- c("duplicate_condition", "condition")
    stop(cond)
  }

  structure(
    list(
      .internal = environment(),
      throw = throw,
      trace_back = trace_back
    ),
    class = c("standalone_err", "standalone"))
})

throw <- err$throw
