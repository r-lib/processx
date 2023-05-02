process_finalize <- function(private) {
  ps <- process_cleanup_list(private)
  ps::ps_kill_parallel(ps, private$cleanup_grace)
}

process_cleanup_list <- function(private) {
  ps <- list()

  if (private$cleanup) {
    # Can't be created in advance because the ps finalizer might run first
    handle <- ps::ps_handle(private$pid, as.POSIXct(private$starttime))
    ps <- c(ps, list(handle))
  }

  if (private$cleanup_tree) {
    ps <- c(ps, ps::ps_find_tree(private$tree_id))
  }

  ps
}

session_finalize <- function(node) {
  ps <- list()
  grace <- 0

  while (!node_is_root(node)) {
    private <- wref_key(node_value(node))
    ps <- c(ps, process_cleanup_list(private))

    if (!is.null(private$cleanup_grace)) {
      grace <- max(grace, private$cleanup_grace)
    }

    node <- node_next(node)
  }

  ps::ps_kill_parallel(ps, grace)
}

wref_key <- function(x) .Call(c_processx__wref_key, x)
node_is_root <- function(x) is.null(node_next(x))
node_prev <- function(x) x[[1]]
node_next <- function(x) x[[2]]
node_value <- function(x) x[[3]]
