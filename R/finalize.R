# Called from the C finalizer of the process handle (Unix only), when
# the process object is garbage collected.
process_finalize <- function(private) {
  cleanup_kill(list(private), private$cleanup_grace)
}

# Called on session exit (Unix only), with the head of the list of
# processes that are still alive.
session_finalize <- function(node) {
  privates <- list()
  grace <- 0

  while (!node_is_root(node)) {
    private <- wref_key(node_value(node))
    if (!is.null(private)) {
      privates <- c(privates, list(private))
      if (!is.null(private$cleanup_grace)) {
        grace <- max(grace, private$cleanup_grace)
      }
    }
    node <- node_next(node)
  }

  cleanup_kill(privates, grace)
}

# Kill all processes (and their process groups) that were started with
# `cleanup = TRUE`, and the process trees of the ones started with
# `cleanup_tree = TRUE`. All processes are killed in parallel: first
# they get a SIGTERM, then we wait at most `grace` seconds for them to
# exit, then the survivors get a SIGKILL.
#
# The process groups are signalled via processx's own handle, so this
# works without ps support. The handle skips processes whose exit
# status was already collected, so we never signal a reused pid.
cleanup_kill <- function(privates, grace) {
  privates <- Filter(function(p) isTRUE(p$cleanup), privates)
  if (length(privates) == 0) {
    return(invisible())
  }

  grace <- if (is.null(grace)) 0 else grace
  deadline <- Sys.time() + grace

  if (grace > 0) {
    for (p in privates) cleanup_signal_group(p, 15L) # SIGTERM
  }

  # Process trees, ps waits for them in parallel, and sends SIGKILL
  # to the ones that are still alive after the grace period.
  trees <- Filter(function(p) isTRUE(p$cleanup_tree), privates)
  if (length(trees) > 0 && ps::ps_is_supported()) {
    tree <- unlist(
      lapply(trees, function(p) {
        tryCatch(ps::ps_find_tree(p$tree_id), error = function(e) list())
      }),
      recursive = FALSE
    )
    if (length(tree) > 0) {
      tryCatch(
        ps::ps_kill(tree, grace = grace * 1000),
        error = function(e) NULL
      )
    }
  }

  # Wait for the rest of the grace period for the process group leaders
  if (grace > 0) {
    for (p in privates) {
      left <- as.double(deadline - Sys.time(), units = "secs")
      if (left <= 0) break
      tryCatch(
        call_with_cleanup(
          c_processx_wait,
          p$status,
          as.integer(left * 1000),
          NULL
        ),
        error = function(e) NULL
      )
    }
  }

  for (p in privates) cleanup_signal_group(p, 9L) # SIGKILL

  invisible()
}

cleanup_signal_group <- function(private, signal) {
  tryCatch(
    .Call(c_processx_signal, private$status, signal, NULL, TRUE),
    error = function(e) FALSE
  )
}

wref_key <- function(x) .Call(c_processx__wref_key, x)
node_is_root <- function(x) is.null(node_next(x))
node_prev <- function(x) x[[1]]
node_next <- function(x) x[[2]]
node_value <- function(x) x[[3]]
