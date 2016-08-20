
is_string <- function(x) {
  is.character(x) &&
  length(x) == 1 &&
  !is.na(x)
}

assert_string <- function(x) {
  stopifnot(is_string(x))
}

assert_character <- function(x) {
  stopifnot(
    is.character(x)
  )
}

is_flag <- function(x) {
  is.logical(x) &&
  length(x) == 1 &&
  !is.na(x)
}

assert_flag_or_string <- function(x) {
  stopifnot(
    is_flag(x) || is_string(x)
  )
}
