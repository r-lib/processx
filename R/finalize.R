process_finalize <- function(private) {
  ps <- list()

  if (private$cleanup) {
    # Can't be created in advance because the ps finalizer might run first
    handle <- ps::ps_handle(private$pid, as.POSIXct(private$starttime))
    ps <- c(ps, list(handle))
  }
  if (private$cleanup_tree) {
    ps <- c(ps, ps::ps_find_tree(private$tree_id))
  }

  ps::ps_kill_parallel(ps, private$cleanup_grace)
}
