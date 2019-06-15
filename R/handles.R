
#' OS handles
#'
#' Helper functions to create R objects that refer to OS specific
#' handles. These are `HANDLE`s on Windows and file descriptors on Unix-like
#' systems.
#'
#' `handle_create()` creates a handle object, from a description.
#' This is an external pointer, pointing to a `HANDLE` (Windows) or an
#' `int` (file descriptor, Unix).
#'
#' `handle_describe()` creates an R string that is a description of the
#' OS handle.
#'
#' These functions are for advanced users, and are considered as
#' experimental currently. They might change in future processx versions.
#'
#' @param desc An integer or string, the description of an OS handle.
#' @param handle A `processx_handle` S3 object, an external pointer to
#'   an OS handle.
#' @return `handle_create()` returns a `processx_handle` S3 object, which
#'   is an external pointer to an OS handle.
#'
#' `handle_describe()` returns a string.
#'
#' @export

handle_create <- function(desc) {
  assert_that(is_string(desc) || is_integerish_scalar(desc))
  if (is.integer(desc)) desc <- as.character(desc)
  .Call(c_processx_handle_create, desc)
}

#' @rdname handle_create
#' @export

handle_describe <- function(handle) {
  assert_that(inherits(handle, "processx_handle"))
  .Call(c_processx_handle_describe, handle)
}
