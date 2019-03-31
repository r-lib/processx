#' Call a native function with correct resource cleanup
#'
#' This function is similar to [base::.Call()], but allows proper
#' resource cleanup, via exit handlers.
#'
#' @param cfun A [base::RegisteredNativeSymbol] object.
#' @param ... Arguments to pass to `cfun`.
#'
#' @section Examples:
#' ```
#' savecall(c_fun1, arg1, arg2)
#' ```
#'
#' @seealso the README file of the package for usage.

safecall <- function(cfun, ...) {
  if (!inherits(cfun, "CallRoutine") ||
      !inherits(cfun$address, "RegisteredNativeSymbol")) {
    stop("Not a .Call routine")
  }
  .Call(c_safecall, cfun$address, cfun$numParameters, list(...))
}
