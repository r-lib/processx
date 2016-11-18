
# 1.0.0.9000

Rewrite the internals, to use `system()` instead of `pipe()`.
`pipe()` was easier to use, but when the R session is closed
there is no way to invoke a finalizer to kill the subprocesses,
and the R session just hangs, waiting for the `pipe()` to close.

In this new version we avoid these problems by using `system()`
instead of `pipe()`.

# 1.0.0

First public release.
