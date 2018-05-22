
#' @export

conn_pipepair <- function(encoding = "") {
  assert_that(is_string(encoding))
  .Call(c_processx_connection_create_pipepair, encoding)
}
