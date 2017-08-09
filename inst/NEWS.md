
# 2.1.0

* `supervise` option to kill child process if R crashes (@wch).

* Add `get_output_file` and `get_error_file`, `has_output_connection()`
  and `has_error_connection()` methods (@wch).

* `stdout` and `stderr` default to `NULL` now, i.e. they are
  discarded (@wch).

* Fix undefined behavior when stdout/stderr was read out after the
  process was already finalized, on Unix.

* `run()`: Better message on interruption, kill process when interrupted.

* Unix: better kill count on unloading the package.

* Unix: make wait() work when SIGCHLD is not delivered for some reason.

* Unix: close inherited file descriptors more conservatively.

* Fix a race condition and several memory leaks on Windows.

* Fixes when running under job control that does not allow breaking away
  from the job, on Windows.

* Fix compilation on Solaris.

# 2.0.0

First public release.
