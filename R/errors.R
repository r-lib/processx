
# # Standalone file for better error handling ----------------------------
#
# If can allow package dependencies, then you are probably better off
# using rlang's functions for errors.
#
# The canonical location of this file is in the processx package:
# https://github.com/r-lib/processx/blob/main/R/errors.R
#
# ## Dependencies
# - rstudio-detect.R for better printing in RStudio
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
# new_cond(..., call. = TRUE, domain = NA)
# new_error(..., call. = TRUE, domain = NA)
# throw(cond, parent = NULL)
# entrace_call(.NAME, ...)
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
#
# ### 1.2.4 -- 2021-04-01
#
# * Allow omitting the call with call. = FALSE in `new_cond()`, etc.
#
# ### 1.3.0 -- 2021-04-19
#
# * Avoid embedding calls in trace with embed = FALSE.
#
# ### 2.0.0 -- 2021-04-19
#
# * Versioned classes and print methods
#
# ### 2.0.1 -- 2021-06-29
#
# * Do not convert error messages to native encoding before printing,
#   to be able to print UTF-8 error messages on Windows.
#
# ### 2.0.2 -- 2021-09-07
#
# * Do not translate error messages, as this converts them to the native
#   encoding. We keep messages in UTF-8 now.
#
# ### 3.0.0 -- 2022-04-19
#
# * Remove `catch_rethrow()` and `rethrow()`, in favor of a cleaner
#   implementation.

err <- local({

  # -- dependencies -----------------------------------------------------
  rstudio_detect <- rstudio$detect

  # -- condition constructors -------------------------------------------

  #' Create a new condition
  #'
  #' @noRd
  #' @param ... Parts of the error message, they will be converted to
  #'   character and then concatenated, like in [stop()].
  #' @param call. A call object to include in the condition, or `TRUE`
  #'   or `NULL`, meaning that [throw()] should add a call object
  #'   automatically. If `FALSE`, then no call is added.
  #' @param domain Translation domain, see [stop()]. We set this to
  #'   `NA` by default, which means that no translation occurs. This
  #'   has the benefit that the error message is not re-encoded into
  #'   the native locale.
  #' @return Condition object. Currently a list, but you should not rely
  #'   on that.

  new_cond <- function(..., call. = TRUE, domain = NA) {
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

  new_error <- function(..., call. = TRUE, domain = NA) {
    cond <- new_cond(..., call. = call., domain = domain)
    class(cond) <- c("rlib_error_3_0", "rlib_error", "rlang_error", "error", "condition")
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
  #' @param parent Parent condition.
  #' @param frame The throwing context. Can be used to hide frames from
  #'   the backtrace.

  throw <- function(cond, parent = NULL, frame = parent.frame()) {
    if (!inherits(cond, "condition")) {
      throw(new_error("You can only throw conditions"))
    }
    if (!is.null(parent) && !inherits(parent, "condition")) {
      throw(new_error("Parent condition must be a condition object"))
    }

    if (isTRUE(cond$call)) {
      cond$call <- sys.call(-1) %||% sys.call()
    } else if (identical(cond$call, FALSE)) {
      cond$call <- NULL
    }

    cond$parent <- parent

    # We can set an option to always add the trace to the thrown
    # conditions. This is useful for example in context that always catch
    # errors, e.g. in testthat tests or knitr. This options is usually not
    # set and we signal the condition here
    always_trace <- isTRUE(getOption("rlib_error_always_trace"))
    if (!always_trace) signalCondition(cond)

    if (is.null(cond$`_pid`)) cond$`_pid` <- Sys.getpid()
    if (is.null(cond$`_timestamp`)) cond$`_timestamp` <- Sys.time()

    # If we get here that means that the condition was not caught by
    # an exiting handler. That means that we need to create a trace.
    # If there is a hand-constructed trace already in the error object,
    # then we'll just leave it there.
    if (is.null(cond$trace)) cond <- add_trace_back(cond, frame = frame)

    # Set up environment to store .Last.error, it will be just before
    # baseenv(), so it is almost as if it was in baseenv() itself, like
    # .Last.value. We save the print methods here as well, and then they
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

    # If this is not an error, then we'll just return here. This allows
    # throwing interrupt conditions for example, with the same UI.
    if (! inherits(cond, "error")) return(invisible())

    # Top-level handler, this is intended for testing only for now,
    # and its design might change.
    if (!is.null(th <- getOption("rlib_error_handler")) &&
        is.function(th)) {
      return(th(cond))
    }

    if (.Platform$GUI == "RStudio") {
      # At the RStudio console, we print the error message through
      # conditionMessage() and also add a note about .Last.error.trace.
      # R will potentially truncate the error message, so we make sure
      # that the note is shown. Ideally we would print the error
      # ourselves, but then RStudio would not highlight it.
      max_msg_len <- as.integer(getOption("warning.length"))
      if (is.na(max_msg_len)) max_msg_len <- 1000
      msg <- conditionMessage(cond)
      adv <- format_advice(cond)
      dots <- paste0("\n", style_dots("[...]"))
      if (bytes(msg) + bytes(adv) + bytes(dots) + 5L > max_msg_len) {
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
      out <- format_cond(cond, trace = !is_interactive(), class = FALSE)
      writeLines(out, con = default_output())

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

  # -- rethrowing conditions from C code ---------------------------------

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

  entrace_call <- function(.NAME, ...) {
    call <- sys.call()
    call1 <- sys.call(-1)
    base_frame <- environment()
    withCallingHandlers(
      # do.call to work around an R CMD check issue
      do.call(".Call", list(.NAME, ...)),
      error = function(e) {
        e$call <- call
        name <- native_name(.NAME)
        e2 <- new_error("Native call to `", name, "` failed", call. = call1)
        class(e2) <- c("c_error", "rlib_error_3_0", "rlib_error", "rlang_error", "error", "condition")
        throw(e2, parent = e, frame = base_frame)
      }
    )
  }

  package_env <- topenv()

  #' Version of entrace_call that supports cleancall
  #'
  #' This function is the same as [entrace_call()], except that it
  #' uses cleancall's [.Call()] wrapper, to enable resource cleanup.
  #' See https://github.com/r-lib/cleancall#readme for more about
  #' resource cleanup.
  #'
  #' @noRd
  #' @param .NAME Compiled function to call, see [.Call()].
  #' @param ... Function arguments, see [.Call()].
  #' @return Result of the call.

  entrace_call_with_cleanup <- function(.NAME, ...) {
    call <- sys.call()
    call1 <- sys.call(-1)
    base_frame <- environment()
    withCallingHandlers(
      package_env$call_with_cleanup(.NAME, ...),
      error = function(e) {
        e$call <- call
        name <- native_name(.NAME)
        e2 <- new_error("Native call to ", name, " failed", call. = call1)
        class(e2) <- c("c_error", "rlib_error_3_0", "rlib_error", "rlang_error", "error", "condition")
        throw(e2, parent = e, frame = base_frame)
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

  add_trace_back <- function(cond, frame = NULL) {

    idx <- seq_len(sys.parent(1L))
    frames <- sys.frames()[idx]

    # TODO: remove embedded objects from calls
    calls <- as.list(sys.calls()[idx])
    parents <- sys.parents()[idx]
    namespaces <- unlist(lapply(
      seq_along(frames),
      function(i) {
        env_label(topenvx(environment(sys.function(i))))
      }
    ))
    pids <- rep(cond$`_pid` %||% Sys.getpid(), length(calls))

    mch <- match(format(frame), sapply(frames, format))
    if (is.na(mch)) {
      visibles <- TRUE
    } else {
      visibles <- c(rep(TRUE, mch), rep(FALSE, length(frames) - mch))
    }

    cond$trace <- new_trace(
      calls,
      parents,
      visibles = visibles,
      namespaces,
      # TODO: :: and :::
      scopes = ifelse(is.na(namespaces), "global", ":::"),
      pids
    )

    cond
  }

  topenvx <- function(x) {
    topenv(x, matchThisEnv = err_env)
  }

  new_trace <- function (calls, parents, visibles, namespaces, scopes, pids) {
    trace <- data.frame(
      stringsAsFactors = FALSE,
      parent = parents,
      visible = visibles,
      namespace = namespaces,
      scope = scopes,
      pid = pids
    )
    trace$call <- calls

    class(trace) <- c("rlib_trace_3_0", "rlang_trace", "rlib_trace", "tbl", "data.frame")
    trace
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
      return(env_name(package_env))
    }
    if (identical(env, globalenv())) {
      return(NA_character_)
    }
    if (identical(env, baseenv())) {
      return("base")
    }
    if (identical(env, emptyenv())) {
      return("empty")
    }
    nm <- environmentName(env)
    if (isNamespace(env)) {
      return(nm)
    }
    nm
  }

  # -- printing ---------------------------------------------------------

  format_rlib_error_3_0 <- function(x, trace = TRUE, class = TRUE, ...) {
    if (has_cli()) {
      format_rlib_error_cli(x, trace, class, ...)
    } else {
      format_rlib_error_plain(x, trace, class, ...)
    }
  }

  format_cond <- format_rlib_error_3_0

  print_rlib_error_3_0 <- function(x, trace = TRUE, class = TRUE, ...) {
    writeLines(format_rlib_error_3_0(x, trace, class, ...))
  }

  format_rlib_trace_3_0 <- function(x, ...) {
    format_rlib_trace_3_0_cli(x, ...)
  }

  format_trace <- format_rlib_trace_3_0

  print_rlib_trace_3_0 <- function(x, ...) {
    writeLines(format_rlib_trace_3_0(x, ...))
  }

  cnd_message_3_0 <- function(c) {
    # TODO: this falls back to rlang currently
    NextMethod()
  }

  # -- printing error with cli ------------------------------------------

  # Error parts:
  # - "Error:" or "Error in " prefix, the latter if the error has a call
  # - the call, possibly syntax highlightedm possibly trimmed (?)
  # - source ref, with link to the file, potentially in a new line in cli
  # - error message, just `conditionMessage()`
  # - advice about .Last.error and/or .Last.error.trace

  format_rlib_error_cli <- function(x, trace = TRUE, class = TRUE, ...) {
    p_class <- if (class) format_class_cli(x)
    p_error <- format_error_heading_cli(x)
    p_call <- format_call_cli(x)
    p_srcref <- format_srcref_cli(x)
    p_msg <- conditionMessage(x)
    p_advice <- if (!trace) format_advice_cli(x) else NULL
    p_trace <- if (trace && !is.null(x$trace)) {
      c("---", format_rlib_trace_3_0_cli(x$trace))
    }

    c(p_class,
      paste0(p_error, p_call, p_srcref),
      p_msg,
      p_advice,
      p_trace)
  }

  format_class_cli <- function(x) {
    cls <- unique(setdiff(class(x), "condition"))
    cls # silence codetools
    cli::format_inline("{.cls {cls}}")
  }

  format_error_heading_cli <- function(x) {
    str_error <- cli::style_bold(cli::col_yellow("Error"))
    if (is.null(conditionCall(x))) {
      paste0(str_error, ": ")
    } else {
      paste0(str_error, " in ")
    }
  }

  format_call_cli <- function(x) {
    call <- conditionCall(x)
    if (is.null(call)) {
      NULL
    } else {
      cli::format_inline("{.code {format(call)}}")
    }
  }

  format_srcref_cli <- function(x) {
    ref <- get_srcref(conditionCall(x))
    if (is.null(ref)) return("")

    link <- if (ref$file != "") {
      cli::style_hyperlink(
        cli::format_inline("{basename(ref$file)}:{ref$line}:{ref$col}"),
        paste0("file://", ref$file),
        params = c(line = ref$line, col = ref$col)
      )

    } else {
      paste0("Line ", ref$line)
    }

    cli::col_silver(paste0(" at ", link))
  }

  str_advice <- "Type .Last.error to see the more details."

  format_advice_cli <- function(x) {
    cli::col_silver(str_advice)
  }

  format_rlib_trace_3_0_cli <- function(x, ...) {
    # TODO
    rlang:::format.rlang_trace(x, simplify = "branch", ...)
  }

  # ----------------------------------------------------------------------

  format_rlib_error_plain <- function(x, ...) {
    # TODO
    rlang:::format.rlang_error(x, ...)
  }

  format_advice <- function(x) {
    if (has_cli()) {
      format_advice_cli(x)
    } else {
      format_advice_nocli(x)
    }
  }

  format_advice_nocli <- function(x, ...) {
    paste0("\n", str_advice)
  }

  # -- styling -----------------------------------------------------------

  cli_version <- function() {
    # this loads cli!
    package_version(asNamespace("cli")[[".__NAMESPACE__."]]$spec[["version"]])
  }

  has_cli <- function() {
    "cli" %in% loadedNamespaces() && cli_version() >= "3.3.0"
  }

  style_dots <- function(x) {
    if (has_cli() && cli::num_ansi_colors() > 1) {
      paste0("\033[0m", "[...]")
    } else {
      "[...]"
    }
  }

  # -- utilities ---------------------------------------------------------

  `%||%` <- function(l, r) if (is.null(l)) r else l

  bytes <- function(x) {
    nchar(x, type = "bytes")
  }

  get_srcref <- function(call) {
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
      file <- ""
    }
    line <- utils::getSrcLocation(call) %||% ""
    col <- utils::getSrcLocation(call, which = "column") %||% ""
    list(file = file, line = line, col = col)
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

  no_sink <- function() {
    sink.number() == 0 && sink.number("message") == 2
  }

  rstudio_stdout <- function() {
    rstudio <- rstudio_detect()
    rstudio$type %in% c(
      "rstudio_console",
      "rstudio_console_starting",
      "rstudio_build_pane",
      "rstudio_job",
      "rstudio_render_pane"
    )
  }

  default_output <- function() {
    if ((is_interactive() || rstudio_stdout()) && no_sink()) {
      stdout()
    } else {
      stderr()
    }
  }

  onload_hook <- function() {
    reg_env <- Sys.getenv("R_LIB_ERROR_REGISTER_PRINT_METHODS", "TRUE")
    if (tolower(reg_env) != "false") {
      registerS3method("format", "rlib_error_3_0", format_rlib_error_3_0, baseenv())
      registerS3method("format", "rlib_trace_3_0", format_rlib_trace_3_0, baseenv())
      registerS3method("print", "rlib_error_3_0", print_rlib_error_3_0, baseenv())
      registerS3method("print", "rlib_trace_3_0", print_rlib_trace_3_0, baseenv())
      registerS3method("conditionMessage", "rlib_error_3_0", cnd_message_3_0, baseenv())
    }
  }

  native_name <- function(x) {
    if (inherits(x, "NativeSymbolInfo")) {
      x$name
    } else {
      format(x)
    }
  }

  # -- public API --------------------------------------------------------

  err_env <- environment()
  parent.env(err_env) <- baseenv()

  structure(
    list(
      .internal      = err_env,
      new_cond       = new_cond,
      new_error      = new_error,
      throw          = throw,
      entrace_call   = entrace_call,
      add_trace_back = add_trace_back,
      onload_hook    = onload_hook
    ),
    class = c("standalone_errors", "standalone"))
})

# These are optional, and feel free to remove them if you prefer to
# call them through the `err` object.

new_cond  <- err$new_cond
new_error <- err$new_error
throw     <- err$throw
entrace_call <- err$entrace_call
entrace_call_with_cleanup <- err$.internal$entrace_call_with_cleanup
