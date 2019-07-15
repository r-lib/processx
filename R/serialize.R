
#' Serialize an R object into a raw vector
#'
#' Compared to [serialize()], it uses `xdr = FALSE`, `ascii = FALSE`, and
#' `version` is 3 for R >= 3.5.0 and 2 otherwise.
#
#' @param x Object to serialize.
#' @return Raw vector, serialized `x`.
#'
#' @export
#' @family serialization
#' @examples
#' x <- 1:10
#' serialize_to_raw(x)
#' unserialize_from_raw(serialize_to_raw(x))

serialize_to_raw <- function(x) {
  rethrow_call(c_processx_serialize_to_raw, x, serialization_version)
}

#' Unserialize an R object from a raw vector
#'
#' @param x Raw vector.
#' @return Unserialized object.
#'
#' @export
#' @family serialization
#' @examples
#' x <- 1:10
#' serialize_to_raw(x)
#' unserialize_from_raw(serialize_to_raw(x))

unserialize_from_raw <- function(x) {
  rethrow_call(c_processx_unserialize_from_raw, x)
}
