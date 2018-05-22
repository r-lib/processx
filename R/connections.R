
#' @export

conn_create_pipepair <- function(encoding = "") {
  assert_that(is_string(encoding))
  .Call(c_processx_connection_create_pipepair, encoding)
}

#' @export

conn_get_description <- function(con)  {
  assert_that(is_connection(con))
  .Call(c_processx_connection_get_description, con)
}

#' @export

conn_create_description <- function(description) {
  assert_that(is_string(description))
  .Call(c_processx_connection_create_description, description)
}
