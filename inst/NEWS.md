
# processx 3.1.0

* Fix interference with the parallel package, and other packages that
  redefine the `SIGCHLD` signal handler on Unix. If the processx signal
  handler is overwritten, we might miss the exit status of some processes
  (they are set to `NA`).

* `run()` and  `process$new()` allow specifying the working directory
  of the process (#63).

* Make the debugme package an optional dependency (#74).

* processx is now compatible with R 3.1.x.

* Allow polling more than 64 connections on Windows, by using IOCP
  instead of `WaitForMultipleObjects()` (#81, #106).

* Fix a race condition on Windows, when creating named pipes for stdout
  or stderr. The client sometimes didn't wait for the server, and processx
  failed with ERROR_PIPE_BUSY (231, All pipe instances are busy).

# processx 3.0.3

* Fix a crash on windows when trying to run a non-existing command (#90)

* Fix a race condition in `process$restart()`

* `run()` and `process$new()` do not support the `commandline` argument
  any more, because process cleanup is error prone with an intermediate
  shell. (#88)

* `processx` process objects no longer use R connection objects,
  because the R connection API was retroactive made private by R-core
  `processx` uses its own connection class now to manage standard output
  and error of the process.

* The encoding of the standard output and error can be specified now,
  and `processx` re-encodes `stdout` and `stderr` in UTF-8.

* Cloning of process objects is disables now, as it is likely that it
  causes problems (@wch).

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

# processx 2.0.0.1

This is an unofficial release, created by CRAN, to fix compilation on
Solaris.

# processx 2.0.0

First public release.
