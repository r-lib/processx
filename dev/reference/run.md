# Run external command, and wait until finishes

`run` provides an interface similar to
[`base::system()`](https://rdrr.io/r/base/system.html) and
[`base::system2()`](https://rdrr.io/r/base/system2.html), but based on
the [process](http://processx.r-lib.org/dev/reference/process.md) class.
This allows some extra features, see below.

## Usage

``` r
run(
  command = NULL,
  args = character(),
  error_on_status = TRUE,
  wd = NULL,
  echo_cmd = FALSE,
  echo = FALSE,
  spinner = FALSE,
  timeout = Inf,
  stdout = "|",
  stderr = "|",
  stdout_line_callback = NULL,
  stdout_callback = NULL,
  stderr_line_callback = NULL,
  stderr_callback = NULL,
  stderr_to_stdout = FALSE,
  stdin = NULL,
  env = NULL,
  windows_verbatim_args = FALSE,
  windows_hide_window = FALSE,
  encoding = "",
  cleanup_tree = FALSE,
  pty = FALSE,
  pty_options = list(),
  ...
)
```

## Arguments

- command:

  Character scalar, the command to run. If you are running `.bat` or
  `.cmd` files on Windows, make sure you read the 'Batch files' section
  in the [process](http://processx.r-lib.org/dev/reference/process.md)
  manual page.

- args:

  Character vector, arguments to the command.

- error_on_status:

  Whether to throw an error if the command returns with a non-zero
  status, or it is interrupted. The error classes are
  `system_command_status_error` and `system_command_timeout_error`,
  respectively, and both errors have class `system_command_error` as
  well. See also "Error conditions" below.

- wd:

  Working directory of the process. If `NULL`, the current working
  directory is used.

- echo_cmd:

  Whether to print the command to run to the screen.

- echo:

  Whether to print the standard output and error to the screen. Note
  that the order of the standard output and error lines are not
  necessarily correct, as standard output is typically buffered. If the
  standard output and/or error is redirected to a file or they are
  ignored, then they also not echoed.

- spinner:

  Whether to show a reassuring spinner while the process is running.

- timeout:

  Timeout for the process, in seconds, or as a `difftime` object. If it
  is not finished before this, it will be killed.

- stdout:

  What to do with the standard output. By default it is collected in the
  result, and you can also use the `stdout_line_callback` and
  `stdout_callback` arguments to pass callbacks for output. If it is the
  empty string (`""`), then the child process inherits the standard
  output stream of the R process. (If the main R process does not have a
  standard output stream, e.g. in RGui on Windows, then an error is
  thrown.) If it is `NULL`, then standard output is discarded. If it is
  a string other than `"|"` and `""`, then it is taken as a file name
  and the output is redirected to this file.

- stderr:

  What to do with the standard error. By default it is collected in the
  result, and you can also use the `stderr_line_callback` and
  `stderr_callback` arguments to pass callbacks for output. If it is the
  empty string (`""`), then the child process inherits the standard
  error stream of the R process. (If the main R process does not have a
  standard error stream, e.g. in RGui on Windows, then an error is
  thrown.) If it is `NULL`, then standard error is discarded. If it is a
  string other than `"|"` and `""`, then it is taken as a file name and
  the standard error is redirected to this file.

- stdout_line_callback:

  `NULL`, or a function to call for every line of the standard output.
  See `stdout_callback` and also more below.

- stdout_callback:

  `NULL`, or a function to call for every chunk of the standard output.
  A chunk can be as small as a single character. At most one of
  `stdout_line_callback` and `stdout_callback` can be non-`NULL`.

- stderr_line_callback:

  `NULL`, or a function to call for every line of the standard error.
  See `stderr_callback` and also more below.

- stderr_callback:

  `NULL`, or a function to call for every chunk of the standard error. A
  chunk can be as small as a single character. At most one of
  `stderr_line_callback` and `stderr_callback` can be non-`NULL`.

- stderr_to_stdout:

  Whether to redirect the standard error to the standard output.
  Specifying `TRUE` here will keep both in the standard output,
  correctly interleaved. However, it is not possible to deduce where
  pieces of the output were coming from. If this is `TRUE`, the standard
  error callbacks (if any) are never called.

- stdin:

  What to do with the standard input. By default it is ignored (`NULL`).
  It can be a file name, to redirect the contents of a file to the
  standard input. When `pty = TRUE`, `stdin` can only be `NULL` (no
  input) or a file path (whose contents are fed to the process via the
  PTY).

- env:

  Environment variables of the child process. If `NULL`, the parent's
  environment is inherited. On Windows, many programs cannot function
  correctly if some environment variables are not set, so we always set
  `HOMEDRIVE`, `HOMEPATH`, `LOGONSERVER`, `PATH`, `SYSTEMDRIVE`,
  `SYSTEMROOT`, `TEMP`, `USERDOMAIN`, `USERNAME`, `USERPROFILE` and
  `WINDIR`. To append new environment variables to the ones set in the
  current process, specify `"current"` in `env`, without a name, and the
  appended ones with names. The appended ones can overwrite the current
  ones.

- windows_verbatim_args:

  Whether to omit the escaping of the command and the arguments on
  windows. Ignored on other platforms.

- windows_hide_window:

  Whether to hide the window of the application on windows. Ignored on
  other platforms.

- encoding:

  The encoding to assume for `stdout` and `stderr`. By default the
  encoding of the current locale is used. Note that `processx` always
  reencodes the output of both streams in UTF-8 currently. Use
  `"binary"` to collect the raw bytes without any conversion: `stdout`
  and `stderr` in the return value will be raw vectors instead of
  character strings. Line callbacks are not supported in binary mode.

- cleanup_tree:

  Whether to clean up the child process tree after the process has
  finished.

- pty:

  Whether to use a pseudo-terminal (PTY) for the process. Supported on
  Unix and on Windows 10 version 1809 or later (via ConPTY). When
  `TRUE`, stdout and stderr are merged into a single stream (accessible
  via `$stdout` in the result), and `$stderr` is always `NULL`. The
  process sees a real terminal, so programs that disable colour or
  interactive features when not attached to a terminal will behave as if
  they are. `stdout` and `stderr` must be left at their defaults
  (`"|"`), and `stderr_to_stdout`, `stderr_callback`, and
  `stderr_line_callback` must not be set.

- pty_options:

  Options for the PTY, a named list. See
  [`default_pty_options()`](http://processx.r-lib.org/dev/reference/default_pty_options.md)
  for the available options and their defaults.

- ...:

  Extra arguments are passed to `process$new()`, see
  [process](http://processx.r-lib.org/dev/reference/process.md). Note
  that you cannot pass `stout` or `stderr` here, because they are used
  internally by `run()`. You can use the `stdout_callback`,
  `stderr_callback`, etc. arguments to manage the standard output and
  error, or the
  [process](http://processx.r-lib.org/dev/reference/process.md) class
  directly if you need more flexibility.

## Value

A list with components:

- status The exit status of the process. If this is `NA`, then the
  process was killed and had no exit status.

- stdout The standard output of the command, in a character scalar.

- stderr The standard error of the command, in a character scalar.

- timeout Whether the process was killed because of a timeout.

## Details

`run` supports

- Specifying a timeout for the command. If the specified time has
  passed, and the process is still running, it will be killed (with all
  its child processes).

- Calling a callback function for each line or each chunk of the
  standard output and/or error. A chunk may contain multiple lines, and
  can be as short as a single character.

- Cleaning up the subprocess, or the whole process tree, before exiting.

## Callbacks

Some notes about the callback functions. The first argument of a
callback function is a character scalar (length 1 character), a single
output or error line. The second argument is always the
[process](http://processx.r-lib.org/dev/reference/process.md) object.
You can manipulate this object, for example you can call `$kill()` on it
to terminate it, as a response to a message on the standard output or
error.

## Error conditions

`run()` throws error condition objects if the process is interrupted,
timeouts or fails (if `error_on_status` is `TRUE`):

- On interrupt, a condition with classes `system_command_interrupt`,
  `interrupt`, `condition` is signalled. This can be caught with
  `tryCatch(..., interrupt = ...)`.

- On timeout, a condition with classes `system_command_timeout_error`,
  `system_command_error`, `error`, `condition` is thrown.

- On error (if `error_on_status` is `TRUE`), an error with classes
  `system_command_status_error`, `system_command_error`, `error`,
  `condition` is thrown.

All of these conditions have the fields:

- `message`: the error message,

- `stderr`: the standard error of the process, or the standard output of
  the process if `stderr_to_stdout` was `TRUE`.

- `call`: the captured call to `run()`.

- `echo`: the value of the `echo` argument.

- `stderr_to_stdout`: the value of the `stderr_to_stdout` argument.

- `status`: the exit status for `system_command_status_error` errors.

## Examples

``` r
# This works on Unix systems
run("ls")
#> $status
#> [1] 0
#> 
#> $stdout
#> [1] "base64_decode.html\ncurl_fds.html\ndefault_pty_options.html\nfigures\nindex.html\npoll.html\nprocess.html\nprocess_initialize.html\nprocessx-package.html\nprocessx_connections.html\nprocessx_fifos.html\nprocessx_sockets.html\n"
#> 
#> $stderr
#> [1] ""
#> 
#> $timeout
#> [1] FALSE
#> 
system.time(run("sleep", "10", timeout = 1, error_on_status = FALSE))
#>    user  system elapsed 
#>   0.006   0.015   0.013 
system.time(
  run(
    "sh", c("-c", "for i in 1 2 3 4 5; do echo $i; sleep 1; done"),
    timeout = 2, error_on_status = FALSE
  )
)
#>    user  system elapsed 
#>   0.003   0.010   1.002 
if (FALSE) {
# This works on Windows systems, if the ping command is available
run("ping", c("-n", "1", "127.0.0.1"))
run("ping", c("-n", "6", "127.0.0.1"), timeout = 1,
    error_on_status = FALSE)
}
```
