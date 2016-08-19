
assert_string <- function(x) {
  stopifnot(
    is.character(x),
    length(x) == 1,
    !is.na(x)
  )
}

assert_character <- function(x) {
  stopifnot(
    is.character(x)
  )
}
