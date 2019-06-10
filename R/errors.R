
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

  new_trace <- function (calls, parents, envs){
    indices <- seq_along(calls)
    structure(list(calls = calls, parents = parents, envs = envs,
                   indices = indices), class = "rlang_trace")
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

  stop <- function(..., call. = TRUE, domain = NULL, parent = NULL) {
    args <- list(...)

    if (length(args) == 1L && inherits(args[[1L]], "condition")) {
      if (nargs() > 1L) warning("additional arguments in stop()")
      cond <- args[[1L]]
      cond$parent <- parent
      message <- conditionMessage(cond)
      call. <- conditionCall(cond)
      if (is.null(call.) || isTRUE(call.)) call. <- sys.call(-1)

    } else {
      message <- .makeMessage(..., domain = domain)
      if (is.null(call.) || isTRUE(call.)) call. <- sys.call(-1)
      cond <- structure(
        list(message = message, call = call., parent = parent),
        class = c("simpleError", "error", "condition"))
    }

    class(cond) <- rev(unique(rev(c(class(cond),
                                    "rlang_error", "error", "condition"))))
    signalCondition(cond)

    if (! "org:r-lib" %in% search()) {
      do.call("attach", list(new.env(), pos = length(search()),
                             name = "org:r-lib"))
    }
    env <- as.environment("org:r-lib")

    cond$trace <- trace_back()
    conditionMessage(cond)
    env$.Last.error <- cond

    class(cond) <- c("duplicate_condition", "condition")
    base::stop(cond)
  }

  rethrow <- function(expr, ..., finally = NULL) {
    cl_wch <- cl_tc <- match.call()
    anms <- names(cl_wch)

    cl_wch[[1]] <- quote(withCallingHandlers)
    if ("finally" %in% anms) cl_wch <- cl_wch[anms != "finally"]
    error <- NULL
    saver <- function(e) { e$trace <- trace_back(); error <<- e }
    cl_wch[3:length(cl_wch)] <- list(saver)

    cl_tc[[1]] <- quote(tryCatch)
    cl_tc[["expr"]] <- quote(eval(cl_wch))
    handlers <- list(...)
    for (h in names(handlers)) {
      cl_tc[[h]] <- function(e) handlers[[h]](error)
    }

    eval(cl_tc)
  }

  structure(
    list(
      .internal = environment(),
      stop = stop,
      trace_back = trace_back,
      rethrow = rethrow
    ),
    class = c("standalone_err", "standalone"))
})

stop <- err$stop
