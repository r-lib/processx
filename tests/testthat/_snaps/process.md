# post processing

    Code
      p$get_result()
    Condition
      Error in `process_get_result()`:
      ! ! Process is still alive

# cleanup_tree = TRUE overrides cleanup = FALSE

    Code
      p <- process$new(px, c("return", "0"), cleanup = FALSE, cleanup_tree = TRUE)
    Condition
      Warning in `process_initialize()`:
      `cleanup_tree` overrides `cleanup`, and process will be killed on GC

# kill_tree() errors if ps does not support the platform

    Code
      p$kill_tree()
    Condition
      Error in `process_kill_tree()`:
      ! ! kill_tree is not supported on this platform

