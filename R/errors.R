
# # Standalone file for better error handling ----------------------------
#
# If can allow package dependencies, then you are probably better off
# using rlang's functions for errors.
#
# The canonical location of this file is in the processx package:
# https://github.com/r-lib/processx/master/R/errors.R
#
# ## Features
#
# - Throw conditions and errors with the same API.
# - Automatically captures the right calls and adds them to the conditions.
# - Sets `.Last.error`, so you can easily inspect the errors, even if they
#   were not caught.
# - It only sets `.Last.error` for the errors that are not caught.
# - Hierarchical errors, to allow higher level error messages, that are
#   more meaningful for the users, while also keeping the lower level
#   details in the error object. (So in `.Last.error` as well.)
# - `.Last.error` always includes a stack trace. (The stack trace is
#   common for the whole error hierarchy.) The trace is accessible within
#   the error, e.g. `.Last.error$trace`. The trace of the last error is
#   also at `.Last.error.trace`.
# - Can merge errors and traces across multiple processes.
# - Pretty-print errors and traces, if the cli package is loaded.
# - Automatically hides uninformative parts of the stack trace when
#   printing.
#
# ## API
#
# ```
# new_cond(..., call. = TRUE, domain = NULL)
# new_error(..., call. = TRUE, domain = NULL)
# throw(cond, parent = NULL)
# catch_rethrow(expr, ...)
# rethrow(expr, cond)
# rethrow_call(.NAME, ...)
# add_trace_back(cond)
# ```
#
# ## Roadmap:
# - better printing of anonymous function in the trace
#
# ## NEWS:
#
# ### 1.0.0 -- 2019-06-18
#
# * First release.
#
# ### 1.0.1 -- 2019-06-20
#
# * Add `rlib_error_always_trace` option to always add a trace
#
# ### 1.0.2 -- 2019-06-27
#
# * Internal change: change topenv of the functions to baseenv()
#
# ### 1.1.0 -- 2019-10-26
#
# * Register print methods via onload_hook() function, call from .onLoad()
# * Print the error manually, and the trace in non-interactive sessions
#
# ### 1.1.1 -- 2019-11-10
#
# * Only use `trace` in parent errors if they are `rlib_error`s.
#   Because e.g. `rlang_error`s also have a trace, with a slightly
#   different format.
#
# ### 1.2.0 -- 2019-11-13
#
# * Fix the trace if a non-thrown error is re-thrown.
# * Provide print_this() and print_parents() to make it easier to define
#   custom print methods.
# * Fix annotating our throw() methods with the incorrect `base::`.
#
# ### 1.2.1 -- 2020-01-30
#
# * Update wording of error printout to be less intimidating, avoid jargon
# * Use default printing in interactive mode, so RStudio can detect the
#   error and highlight it.
# * Add the rethrow_call_with_cleanup function, to work with embedded
#   cleancall.
#
# ### 1.2.2 -- 2020-11-19
#
# * Add the `call` argument to `catch_rethrow()` and `rethrow()`, to be
#   able to omit calls.
#
# ### 1.2.3 -- 2021-03-06
#
# * Use cli instead of crayon

err <- local({

  # -- condition constructors -------------------------------------------

  #' Create a new condition
  #'
  #' @noRd
  #' @param ... Parts of the error message, they will be converted to
  #'   character and then concatenated, like in [stop()].
  #' @param call. A call object to include in the condition, or `TRUE`
  #'   or `NULL`, meaning that [throw()] should add a call object
  #'   automatically.
  #' @param domain Translation domain, see [stop()].
  #' @return Condition object. Currently a list, but you should not rely
  #'   on that.

  new_cond <- function(..., call. = TRUE, domain = NULL) {
    message <- .makeMessage(..., domain = domain)
    structure(
      list(message = message, call = call.),
      class = c("condition"))
  }

  #' Create a new error condition
  #'
  #' It also adds the `rlib_error` class.
  #'
  #' @noRd
  #' @param ... Passed to [new_cond()].
  #' @param call. Passed to [new_cond()].
  #' @param domain Passed to [new_cond()].
  #' @return Error condition object with classes `rlib_error`, `error`
  #'   and `condition`.

  new_error <- function(..., call. = TRUE, domain = NULL) {
    cond <- new_cond(..., call. = call., domain = domain)
    class(cond) <- c("rlib_error", "error", "condition")
    cond
  }

  # -- throwing conditions ----------------------------------------------

  #' Throw a condition
  #'
  #' If the condition is an error, it will also call [stop()], after
  #' signalling the condition first. This means that if the condition is
  #' caught by an exiting handler, then [stop()] is not called.
  #'
  #' @noRd
  #' @param cond Condition object to throw. If it is an error condition,
  #'   then it calls [stop()].
  #' @param parent Parent condition. Use this within [rethrow()] and
  #'   [catch_rethrow()].

  throw <- function(cond, parent = NULL) {
    if (!inherits(cond, "condition")) {
      throw(new_error("You can only throw conditions"))
    }
    if (!is.null(parent) && !inherits(parent, "condition")) {
      throw(new_error("Parent condition must be a condition object"))
    }

    if (isTRUE(cond$call)) {
      cond$call <- sys.call(-1) %||% sys.call()
    }

    # Eventually the nframe numbers will help us print a better trace
    # When a child condition is created, the child will use the parent
    # error object to make note of its own nframe. Here we copy that back
    # to the parent.
    if (is.null(cond$`_nframe`)) cond$`_nframe` <- sys.nframe()
    if (!is.null(parent)) {
      cond$parent <- parent
      cond$call <- cond$parent$`_childcall`
      cond$`_nframe` <- cond$parent$`_childframe`
      cond$`_ignore` <- cond$parent$`_childignore`
    }

    # We can set an option to always add the trace to the thrown
    # conditions. This is useful for example in context that always catch
    # errors, e.g. in testthat tests or knitr. This options is usually not
    # set and we signal the condition here
    always_trace <- isTRUE(getOption("rlib_error_always_trace"))
    if (!always_trace) signalCondition(cond)

    # If this is not an error, then we'll just return here. This allows
    # throwing interrupt conditions for example, with the same UI.
    if (! inherits(cond, "error")) return(invisible())

    if (is.null(cond$`_pid`)) cond$`_pid` <- Sys.getpid()
    if (is.null(cond$`_timestamp`)) cond$`_timestamp` <- Sys.time()

    # If we get here that means that the condition was not caught by
    # an exiting handler. That means that we need to create a trace.
    # If there is a hand-constructed trace already in the error object,
    # then we'll just leave it there.
    if (is.null(cond$trace)) cond <- add_trace_back(cond)

    # Set up environment to store .Last.error, it will be just before
    # baseenv(), so it is almost as if it was in baseenv() itself, like
    # .Last.value. We save the print methos here as well, and then they
    # will be found automatically.
    if (! "org:r-lib" %in% search()) {
      do.call("attach", list(new.env(), pos = length(search()),
                             name = "org:r-lib"))
    }
    env <- as.environment("org:r-lib")
    env$.Last.error <- cond
    env$.Last.error.trace <- cond$trace

    # If we always wanted a trace, then we signal the condition here
    if (always_trace) signalCondition(cond)

    # Top-level handler, this is intended for testing only for now,
    # and its design might change.
    if (!is.null(th <- getOption("rlib_error_handler")) &&
        is.function(th)) {
      th(cond)

    } else {

      if (is_interactive()) {
        # In interactive mode, we print the error message through
        # conditionMessage() and also add a note about .Last.error.trace.
        # R will potentially truncate the error message, so we make sure
        # that the note is shown. Ideally we would print the error
        # ourselves, but then RStudio would not highlight it.
        max_msg_len <- as.integer(getOption("warning.length"))
        if (is.na(max_msg_len)) max_msg_len <- 1000
        msg <- conditionMessage(cond)
        adv <- style_advice(
          "\nType .Last.error.trace to see where the error occured"
        )
        dots <- "\033[0m\n[...]"
        if (bytes(msg) + bytes(adv) + bytes(dots) + 5L> max_msg_len) {
          msg <- paste0(
            substr(msg, 1, max_msg_len - bytes(dots) - bytes(adv) - 5L),
            dots
          )
        }
        cond$message <- paste0(msg, adv)

      } else {
        # In non-interactive mode, we print the error + the traceback
        # manually, to make sure that it won't be truncated by R's error
        # message length limit.
        cat("\n", file = stderr())
        cat(style_error(gettext("Error: ")), file = stderr())
        out <- capture_output(print(cond))
        cat(out, file = stderr(), sep = "\n")
        out <- capture_output(print(cond$trace))
        cat(out, file = stderr(), sep = "\n")

        # Turn off the regular error printing to avoid printing
        # the error twice.
        opts <- options(show.error.messages = FALSE)
        on.exit(options(opts), add = TRUE)
      }

      # Dropping the classes and adding "duplicate_condition" is a workaround
      # for the case when we have non-exiting handlers on throw()-n
      # conditions. These would get the condition twice, because stop()
      # will also signal it. If we drop the classes, then only handlers
      # on "condition" objects (i.e. all conditions) get duplicate signals.
      # This is probably quite rare, but for this rare case they can also
      # recognize the duplicates from the "duplicate_condition" extra class.
      class(cond) <- c("duplicate_condition", "condition")

      stop(cond)
    }
  }

  # -- rethrowing conditions --------------------------------------------

  #' Catch and re-throw conditions
  #'
  #' See [rethrow()] for a simpler interface that handles `error`
  #' conditions automatically.
  #'
  #' @noRd
  #' @param expr Expression to evaluate.
  #' @param ... Condition handler specification, the same way as in
  #'   [withCallingHandlers()]. You are supposed to call [throw()] from
  #'   the error handler, with a new error object, setting the original
  #'   error object as parent. See examples below.
  #' @param call Logical flag, whether to add the call to
  #'   `catch_rethrow()` to the error.
  #' @examples
  #' f <- function() {
  #'   ...
  #'   err$catch_rethrow(
  #'     ... code that potentially errors ...,
  #'     error = function(e) {
  #'       throw(new_error("This will be the child error"), parent = e)
  #'     }
  #'   )
  #' }

  catch_rethrow <- function(expr, ..., call = TRUE) {
    realcall <- if (isTRUE(call)) sys.call(-1) %||% sys.call()
    realframe <- sys.nframe()
    parent <- parent.frame()

    cl <- match.call()
    cl[[1]] <- quote(withCallingHandlers)
    handlers <- list(...)
    for (h in names(handlers)) {
      cl[[h]] <- function(e) {
        # This will be NULL if the error is not throw()-n
        if (is.null(e$`_nframe`)) e$`_nframe` <- length(sys.calls())
        e$`_childcall` <- realcall
        e$`_childframe` <- realframe
        # We drop after realframe, until the first withCallingHandlers
        wch <- find_call(sys.calls(), quote(withCallingHandlers))
        if (!is.na(wch)) e$`_childignore` <- list(c(realframe + 1L, wch))
        handlers[[h]](e)
      }
    }
    eval(cl, envir = parent)
  }

  find_call <- function(calls, call) {
    which(vapply(
      calls, function(x) length(x) >= 1 && identical(x[[1]], call),
      logical(1)))[1]
  }

  #' Catch and re-throw conditions
  #'
  #' `rethrow()` is similar to [catch_rethrow()], but it has a simpler
  #' interface. It catches conditions with class `error`, and re-throws
  #' `cond` instead, using the original condition as the parent.
  #'
  #' @noRd
  #' @param expr Expression to evaluate.
  #' @param ... Condition handler specification, the same way as in
  #'   [withCallingHandlers()].
  #' @param call Logical flag, whether to add the call to
  #'   `rethrow()` to the error.

  rethrow <- function(expr, cond, call = TRUE) {
    realcall <- if (isTRUE(call)) sys.call(-1) %||% sys.call()
    realframe <- sys.nframe()
    withCallingHandlers(
      expr,
      error = function(e) {
        # This will be NULL if the error is not throw()-n
        if (is.null(e$`_nframe`)) e$`_nframe` <- length(sys.calls())
        e$`_childcall` <- realcall
        e$`_childframe` <- realframe
        # We just ignore the withCallingHandlers call, and the tail
        e$`_childignore` <- list(
          c(realframe + 1L, realframe + 1L),
          c(e$`_nframe` + 1L, sys.nframe() + 1L))
        throw(cond, parent = e)
      }
    )
  }

  #' Version of .Call that throw()s errors
  #'
  #' It re-throws error from interpreted code. If the error had class
  #' `simpleError`, like all errors, thrown via `error()` in C do, it also
  #' adds the `c_error` class.
  #'
  #' @noRd
  #' @param .NAME Compiled function to call, see [.Call()].
  #' @param ... Function arguments, see [.Call()].
  #' @return Result of the call.

  rethrow_call <- function(.NAME, ...) {
    call <- sys.call()
    nframe <- sys.nframe()
    withCallingHandlers(
      # do.call to work around an R CMD check issue
      do.call(".Call", list(.NAME, ...)),
      error = function(e) {
        e$`_nframe` <- nframe
        e$call <- call
        if (inherits(e, "simpleError")) {
          class(e) <- c("c_error", "rlib_error", "error", "condition")
        }
        e$`_ignore` <- list(c(nframe + 1L, sys.nframe() + 1L))
        throw(e)
      }
    )
  }

  package_env <- topenv()

  #' Version of rethrow_call that supports cleancall
  #'
  #' This function is the same as [rethrow_call()], except that it
  #' uses cleancall's [.Call()] wrapper, to enable resource cleanup.
  #' See https://github.com/r-lib/cleancall#readme for more about
  #' resource cleanup.
  #'
  #' @noRd
  #' @param .NAME Compiled function to call, see [.Call()].
  #' @param ... Function arguments, see [.Call()].
  #' @return Result of the call.

  rethrow_call_with_cleanup <- function(.NAME, ...) {
    call <- sys.call()
    nframe <- sys.nframe()
    withCallingHandlers(
      package_env$call_with_cleanup(.NAME, ...),
      error = function(e) {
        e$`_nframe` <- nframe
        e$call <- call
        if (inherits(e, "simpleError")) {
          class(e) <- c("c_error", "rlib_error", "error", "condition")
        }
        e$`_ignore` <- list(c(nframe + 1L, sys.nframe() + 1L))
        throw(e)
      }
    )
  }

  # -- create traceback -------------------------------------------------

  #' Create a traceback
  #'
  #' [throw()] calls this function automatically if an error is not caught,
  #' so there is currently not much use to call it directly.
  #'
  #' @param cond Condition to add the trace to
  #'
  #' @return A condition object, with the trace added.

  add_trace_back <- function(cond) {
    idx <- seq_len(sys.parent(1L))
    frames <- sys.frames()[idx]

    parents <- sys.parents()[idx]
    calls <- as.list(sys.calls()[idx])
    envs <- lapply(frames, env_label)
    topenvs <- lapply(
      seq_along(frames),
      function(i) env_label(topenvx(environment(sys.function(i)))))
    nframes <- if (!is.null(cond$`_nframe`)) cond$`_nframe` else sys.parent()
    messages <- list(conditionMessage(cond))
    ignore <- cond$`_ignore`
    classes <- class(cond)
    pids <- rep(cond$`_pid` %||% Sys.getpid(), length(calls))

    if (is.null(cond$parent)) {
      # Nothing to do, no parent

    } else if (is.null(cond$parent$trace) ||
               !inherits(cond$parent, "rlib_error")) {
      # If the parent does not have a trace, that means that it is using
      # the same trace as us. We ignore traces from non-r-lib errors.
      # E.g. rlang errors have a trace, but we do not use that.
      parent <- cond
      while (!is.null(parent <- parent$parent)) {
        nframes <- c(nframes, parent$`_nframe`)
        messages <- c(messages, list(conditionMessage(parent)))
        ignore <- c(ignore, parent$`_ignore`)
      }

    } else {
      # If it has a trace, that means that it is coming from another
      # process or top level evaluation. In this case we'll merge the two
      # traces.
      pt <- cond$parent$trace
      parents <- c(parents, pt$parents + length(calls))
      nframes <- c(nframes, pt$nframes + length(calls))
      ignore <- c(ignore, lapply(pt$ignore, function(x) x + length(calls)))
      envs <- c(envs, pt$envs)
      topenvs <- c(topenvs, pt$topenvs)
      calls <- c(calls, pt$calls)
      messages <- c(messages, pt$messages)
      pids <- c(pids, pt$pids)
    }

    cond$trace <- new_trace(
      calls, parents, envs, topenvs, nframes, messages, ignore, classes,
      pids)

    cond
  }

  topenvx <- function(x) {
    topenv(x, matchThisEnv = err_env)
  }

  new_trace <- function (calls, parents, envs, topenvs, nframes, messages,
                         ignore, classes, pids) {
    indices <- seq_along(calls)
    structure(
      list(calls = calls, parents = parents, envs = envs, topenvs = topenvs,
           indices = indices, nframes = nframes, messages = messages,
           ignore = ignore, classes = classes, pids = pids),
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
    if (identical(env, err_env)) {
      return("")
    }
    if (identical(env, globalenv())) {
      return("global")
    }
    if (identical(env, baseenv())) {
      return("namespace:base")
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

  # -- printing ---------------------------------------------------------

  print_this <- function(x, ...) {
    msg <- conditionMessage(x)
    call <- conditionCall(x)
    cl <- class(x)[1L]
    if (!is.null(call)) {
      cat("<", cl, " in ", format_call(call), ":\n ", msg, ">\n", sep = "")
    } else {
      cat("<", cl, ": ", msg, ">\n", sep = "")
    }

    print_srcref(x$call)

    if (!identical(x$`_pid`, Sys.getpid())) {
      cat(" in process", x$`_pid`, "\n")
    }

    invisible(x)
  }

  print_parents <- function(x, ...) {
    if (!is.null(x$parent)) {
      cat("-->\n")
      print(x$parent)
    }
    invisible(x)
  }

  print_rlib_error <- function(x, ...) {
    print_this(x, ...)
    print_parents(x, ...)
  }

  print_rlib_trace <- function(x, ...) {
    cl <- paste0(" Stack trace:")
    cat(sep = "", "\n", style_trace_title(cl), "\n\n")
    calls <- map2(x$calls, x$topenv, namespace_calls)
    callstr <- vapply(calls, format_call_src, character(1))
    callstr[x$nframes] <-
      paste0(callstr[x$nframes], "\n", style_error_msg(x$messages), "\n")
    callstr <- enumerate(callstr)

    # Ignore what we were told to ignore
    ign <- integer()
    for (iv in x$ignore) {
      if (iv[2] == Inf) iv[2] <- length(callstr)
      ign <- c(ign, iv[1]:iv[2])
    }

    # Plus always ignore the tail. This is not always good for
    # catch_rethrow(), but should be good otherwise
    last_err_frame <- x$nframes[length(x$nframes)]
    if (!is.na(last_err_frame) && last_err_frame < length(callstr)) {
      ign <- c(ign, (last_err_frame+1):length(callstr))
    }

    ign <- unique(ign)
    if (length(ign)) callstr <- callstr[-ign]

    # Add markers for subprocesses
    if (length(unique(x$pids)) >= 2) {
      pids <- x$pids[-ign]
      pid_add <- which(!duplicated(pids))
      pid_str <- style_process(paste0("Process ", pids[pid_add], ":"))
      callstr[pid_add] <- paste0(" ", pid_str, "\n", callstr[pid_add])
    }

    cat(callstr, sep = "\n")
    invisible(x)
  }

  capture_output <- function(expr) {
    if (has_cli()) {
      opts <- options(cli.num_colors = cli::num_ansi_colors())
      on.exit(options(opts), add = TRUE)
    }

    out <- NULL
    file <- textConnection("out", "w", local = TRUE)
    sink(file)
    on.exit(sink(NULL), add = TRUE)

    expr
    if (is.null(out)) invisible(NULL) else out
  }

  is_interactive <- function() {
    opt <- getOption("rlib_interactive")
    if (isTRUE(opt)) {
      TRUE
    } else if (identical(opt, FALSE)) {
      FALSE
    } else if (tolower(getOption("knitr.in.progress", "false")) == "true") {
      FALSE
    } else if (tolower(getOption("rstudio.notebook.executing", "false")) == "true") {
      FALSE
    } else if (identical(Sys.getenv("TESTTHAT"), "true")) {
      FALSE
    } else {
      interactive()
    }
  }

  onload_hook <- function() {
    reg_env <- Sys.getenv("R_LIB_ERROR_REGISTER_PRINT_METHODS", "TRUE")
    if (tolower(reg_env) != "false") {
      registerS3method("print", "rlib_error", print_rlib_error, baseenv())
      registerS3method("print", "rlib_trace", print_rlib_trace, baseenv())
    }
  }

  namespace_calls <- function(call, env) {
    if (length(call) < 1) return(call)
    if (typeof(call[[1]]) != "symbol") return(call)
    pkg <- strsplit(env, "^namespace:")[[1]][2]
    if (is.na(pkg)) return(call)
    call[[1]] <- substitute(p:::f, list(p = as.symbol(pkg), f = call[[1]]))
    call
  }

  print_srcref <- function(call) {
    src <- format_srcref(call)
    if (length(src)) cat(sep = "", " ", src, "\n")
  }

  `%||%` <- function(l, r) if (is.null(l)) r else l

  format_srcref <- function(call) {
    if (is.null(call)) return(NULL)
    file <- utils::getSrcFilename(call)
    if (!length(file)) return(NULL)
    dir <- utils::getSrcDirectory(call)
    if (length(dir) && nzchar(dir) && nzchar(file)) {
      srcfile <- attr(utils::getSrcref(call), "srcfile")
      if (isTRUE(srcfile$isFile)) {
        file <- file.path(dir, file)
      } else {
        file <- file.path("R", file)
      }
    } else {
      file <- "??"
    }
    line <- utils::getSrcLocation(call) %||% "??"
    col <- utils::getSrcLocation(call, which = "column") %||% "??"
    style_srcref(paste0(file, ":", line, ":", col))
  }

  format_call <- function(call) {
    width <- getOption("width")
    str <- format(call)
    callstr <- if (length(str) > 1 || nchar(str[1]) > width) {
      paste0(substr(str[1], 1, width - 5), " ...")
    } else {
      str[1]
    }
    style_call(callstr)
  }

  format_call_src <- function(call) {
    callstr <- format_call(call)
    src <- format_srcref(call)
    if (length(src)) callstr <- paste0(callstr, "\n    ", src)
    callstr
  }

  enumerate <- function(x) {
    paste0(style_numbers(paste0(" ", seq_along(x), ". ")), x)
  }

  map2 <- function (.x, .y, .f, ...) {
    mapply(.f, .x, .y, MoreArgs = list(...), SIMPLIFY = FALSE,
           USE.NAMES = FALSE)
  }

  bytes <- function(x) {
    nchar(x, type = "bytes")
  }

  # -- printing, styles -------------------------------------------------

  has_cli <- function() "cli" %in% loadedNamespaces()

  style_numbers <- function(x) {
    if (has_cli()) cli::col_silver(x) else x
  }

  style_advice <- function(x) {
    if (has_cli()) cli::col_silver(x) else x
  }

  style_srcref <- function(x) {
    if (has_cli()) cli::style_italic(cli::col_cyan(x))
  }

  style_error <- function(x) {
    if (has_cli()) cli::style_bold(cli::col_ed(x)) else x
  }

  style_error_msg <- function(x) {
    sx <- paste0("\n x ", x, " ")
    style_error(sx)
  }

  style_trace_title <- function(x) {
    x
  }

  style_process <- function(x) {
    if (has_cli()) cli::style_bold(x) else x
  }

  style_call <- function(x) {
    if (!has_cli()) return(x)
    call <- sub("^([^(]+)[(].*$", "\\1", x)
    rest <- sub("^[^(]+([(].*)$", "\\1", x)
    if (call == x || rest == x) return(x)
    paste0(cli::col_yellow(call), rest)
  }

  err_env <- environment()
  parent.env(err_env) <- baseenv()

  structure(
    list(
      .internal      = err_env,
      new_cond       = new_cond,
      new_error      = new_error,
      throw          = throw,
      rethrow        = rethrow,
      catch_rethrow  = catch_rethrow,
      rethrow_call   = rethrow_call,
      add_trace_back = add_trace_back,
      onload_hook    = onload_hook,
      print_this     = print_this,
      print_parents  = print_parents
    ),
    class = c("standalone_errors", "standalone"))
})

# These are optional, and feel free to remove them if you prefer to
# call them through the `err` object.

new_cond  <- err$new_cond
new_error <- err$new_error
throw     <- err$throw
rethrow   <- err$rethrow
rethrow_call <- err$rethrow_call
rethrow_call_with_cleanup <- err$.internal$rethrow_call_with_cleanup
