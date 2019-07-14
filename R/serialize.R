
#' @export

serialize_to_raw <- function(x) {
  rethrow_call(c_processx_serialize_to_raw, x, serialization_version)
}

#' @export

unserialize_from_raw <- function(x) {
  rethrow_call(c_processx_unserialize_from_raw, x)
}
