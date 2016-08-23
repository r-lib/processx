
## We have to use an environment here, because we need
## reference semantics
process_connection <- function(con, cleanup = TRUE) {
  class(con) <- unique(c("process_connection", class(con)))

  state <- new.env()
  state$closed <- FALSE
  attr(con, "closed") <- state

  if (cleanup) {
    attr(con, "closed")$con <- con
    reg.finalizer(state, function(e) if (! e$closed) close(e$con), TRUE)
  }

  con
}

#' @export

close.process_connection <- function(con, ...) {

  ## Was closed already
  if (attr(con, "closed")$closed) return(invisible(NULL))

  ## Otherwise try closing it
  res <- withVisible(NextMethod("close"))

  ## Check if it was closed, this is only safe here
  ## because R is single threaded, i.e. no other connection
  ## could be made with the same id, after closing the old one
  ## but before getting here
  if (! con %in% getAllConnections()) attr(con, "closed")$closed <- TRUE

  ## Return result with correct visibility
  if (res$visible) res else invisible(res)
}

is_closed <- function(con)
  UseMethod("is_closed")

#' @export

is_closed.process_connection <- function(con) {
  attr(con, "closed")$closed
}

#' @export

summary.process_connection <- function(object, ...) {
  if (is_closed(object)) {
    cat("A closed connection.\n")
    invisible(object)
  } else {
    NextMethod("summary")
  }
}

#' @export

print.process_connection <- function(x, ...) {
  if (is_closed(x)) {
    cat("A closed connection.\n")
    invisible(x)
  } else {
    NextMethod(x)
  }
}
