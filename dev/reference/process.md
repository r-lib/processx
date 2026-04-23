# External process

Managing external processes from R is not trivial, and this class aims
to help with this deficiency. It is essentially a small wrapper around
the `system` base R function, to return the process id of the started
process, and set its standard output and error streams. The process id
is then used to manage the process.

## Batch files

Running Windows batch files (`.bat` or `.cmd` files) may be complicated
because of the `cmd.exe` command line parsing rules. For example you
cannot easily have whitespace in both the command (path) and one of the
arguments. To work around these limitations you need to start a
`cmd.exe` shell explicitly and use its `call` command. For example:

    process$new("cmd.exe", c("/c", "call", bat_file, "arg 1", "arg 2"))

This works even if `bat_file` contains whitespace characters. For more
information about this, see this processx issue:
https://github.com/r-lib/processx/issues/301

The detailed parsing rules are at
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/cmd

A very good practical guide is at https://ss64.com/nt/syntax-esc.html

## Polling

The `poll_io()` function polls the standard output and standard error
connections of a process, with a timeout. If there is output in either
of them, or they are closed (e.g. because the process exits) `poll_io()`
returns immediately.

In addition to polling a single process, the
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md) function can
poll the output of several processes, and returns as soon as any of them
has generated output (or exited).

**Always call `$poll_io()` (or
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md)) before
reading from the stdout or stderr pipes.** The OS pipe buffer is finite
(typically 64KB on Linux/macOS, ~76KB on Windows). If the child process
fills the pipe buffer before the parent reads from it, the child blocks
waiting for the buffer to drain, while the parent may be waiting for the
child — resulting in a deadlock. Polling drains the buffer and prevents
this. Even a zero-timeout poll (`$poll_io(0)`) is sufficient when you
know output is available; use a positive timeout (or `-1` to wait
indefinitely) when you need to wait for output to arrive.

Note also that `$read_output()` and `$read_error()` may return *less*
data than requested: a single call is not guaranteed to return all
buffered output. Call them in a loop (polling before each read) until
`$is_incomplete_output()` / `$is_incomplete_error()` returns `FALSE` to
collect everything. The `$read_all_output()` and `$read_all_error()`
helpers already do this for you.

## Cleaning up background processes

processx provides several mechanisms to clean up background processes.
See the [Process
cleanup](https://processx.r-lib.org/dev/articles/cleanup.html) article
for a full discussion. A brief summary:

- **Explicit cleanup** (most reliable): call `$kill()` or `$kill_tree()`
  from an [`on.exit()`](https://rdrr.io/r/base/on.exit.html) expression
  or error handler:

    process_manager <- function() {
      on.exit({
        try(p1$kill(), silent = TRUE)
        try(p2$kill(), silent = TRUE)
      }, add = TRUE)
      p1 <- process$new("sleep", "3")
      p2 <- process$new("sleep", "10")
      p1$wait()
      p2$wait()
    }
    process_manager()

If you interrupt `process_manager()` or an error happens then both `p1`
and `p2` are cleaned up immediately.

- **Automatic GC cleanup** (`cleanup = TRUE`, the default): the process
  is killed when the `process` R object is garbage collected. On Unix,
  `kill(-pid, SIGKILL)` is used, which kills the child's whole process
  group (since the child calls `setsid()` on startup). On Windows, the
  child is added to a global Job Object with
  `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, so it is also killed if R exits
  or crashes. GC timing is non-deterministic; prefer
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html) when determinism
  matters.

- **Process tree cleanup** (`cleanup_tree = TRUE`): kills the process
  and all its descendants, including orphaned ones. processx marks each
  child with a unique environment variable (`PROCESSX_<id>=YES`) that is
  inherited by all descendants; `$kill_tree()` uses the *ps* package to
  find and kill every process carrying that variable. On macOS, system
  restrictions may prevent reading other processes' environment, so tree
  cleanup may not work reliably.

- **Linux parent-death signal** (`linux_pdeathsig`): on Linux, the
  kernel can send a signal (e.g. `SIGTERM`) to the child when the parent
  R process exits, including on crash. Pass `linux_pdeathsig = TRUE` for
  `SIGTERM`, or an integer signal number. Ignored on non-Linux
  platforms.

- **Supervisor** (`supervise = TRUE`): a separate native process that
  polls every 200 ms and kills registered children if the parent R
  process dies (including crashes). On Unix it sends SIGTERM then (after
  5 s) SIGKILL. On Windows it sends CTRL+C / WM_CLOSE then hard-kills.
  Note: on Windows, antivirus software may block `supervisor.exe`.

## Methods

### Public methods

- [`process$new()`](#method-process-new)

- [`process$kill()`](#method-process-kill)

- [`process$kill_tree()`](#method-process-kill_tree)

- [`process$signal()`](#method-process-signal)

- [`process$interrupt()`](#method-process-interrupt)

- [`process$get_pid()`](#method-process-get_pid)

- [`process$is_alive()`](#method-process-is_alive)

- [`process$wait()`](#method-process-wait)

- [`process$get_exit_status()`](#method-process-get_exit_status)

- [`process$format()`](#method-process-format)

- [`process$print()`](#method-process-print)

- [`process$get_start_time()`](#method-process-get_start_time)

- [`process$get_end_time()`](#method-process-get_end_time)

- [`process$is_supervised()`](#method-process-is_supervised)

- [`process$supervise()`](#method-process-supervise)

- [`process$read_output()`](#method-process-read_output)

- [`process$read_error()`](#method-process-read_error)

- [`process$read_output_bytes()`](#method-process-read_output_bytes)

- [`process$read_error_bytes()`](#method-process-read_error_bytes)

- [`process$read_output_lines()`](#method-process-read_output_lines)

- [`process$read_error_lines()`](#method-process-read_error_lines)

- [`process$is_incomplete_output()`](#method-process-is_incomplete_output)

- [`process$is_incomplete_error()`](#method-process-is_incomplete_error)

- [`process$has_input_connection()`](#method-process-has_input_connection)

- [`process$has_output_connection()`](#method-process-has_output_connection)

- [`process$has_error_connection()`](#method-process-has_error_connection)

- [`process$has_poll_connection()`](#method-process-has_poll_connection)

- [`process$get_input_connection()`](#method-process-get_input_connection)

- [`process$get_output_connection()`](#method-process-get_output_connection)

- [`process$get_error_connection()`](#method-process-get_error_connection)

- [`process$read_all_output()`](#method-process-read_all_output)

- [`process$read_all_error()`](#method-process-read_all_error)

- [`process$read_all_output_lines()`](#method-process-read_all_output_lines)

- [`process$read_all_error_lines()`](#method-process-read_all_error_lines)

- [`process$write_input()`](#method-process-write_input)

- [`process$get_input_file()`](#method-process-get_input_file)

- [`process$get_output_file()`](#method-process-get_output_file)

- [`process$get_error_file()`](#method-process-get_error_file)

- [`process$poll_io()`](#method-process-poll_io)

- [`process$get_poll_connection()`](#method-process-get_poll_connection)

- [`process$get_result()`](#method-process-get_result)

- [`process$as_ps_handle()`](#method-process-as_ps_handle)

- [`process$get_name()`](#method-process-get_name)

- [`process$get_exe()`](#method-process-get_exe)

- [`process$get_cmdline()`](#method-process-get_cmdline)

- [`process$get_status()`](#method-process-get_status)

- [`process$get_username()`](#method-process-get_username)

- [`process$get_wd()`](#method-process-get_wd)

- [`process$get_cpu_times()`](#method-process-get_cpu_times)

- [`process$get_memory_info()`](#method-process-get_memory_info)

- [`process$suspend()`](#method-process-suspend)

- [`process$resume()`](#method-process-resume)

- [`process$clone()`](#method-process-clone)

------------------------------------------------------------------------

### Method `new()`

Start a new process in the background, and then return immediately.

#### Usage

    process$new(
      command = NULL,
      args = character(),
      stdin = NULL,
      stdout = NULL,
      stderr = NULL,
      pty = FALSE,
      pty_options = list(),
      connections = list(),
      poll_connection = NULL,
      env = NULL,
      cleanup = TRUE,
      cleanup_tree = FALSE,
      wd = NULL,
      echo_cmd = FALSE,
      supervise = FALSE,
      windows_verbatim_args = FALSE,
      windows_hide_window = FALSE,
      windows_detached_process = !cleanup,
      encoding = "",
      post_process = NULL,
      linux_pdeathsig = FALSE
    )

#### Arguments

- `command`:

  Character scalar, the command to run. Note that this argument is not
  passed to a shell, so no tilde-expansion or variable substitution is
  performed on it. It should not be quoted with
  [`base::shQuote()`](https://rdrr.io/r/base/shQuote.html). See
  [`base::normalizePath()`](https://rdrr.io/r/base/normalizePath.html)
  for tilde-expansion. If you want to run `.bat` or `.cmd` files on
  Windows, make sure you read the 'Batch files' section above.

- `args`:

  Character vector, arguments to the command. They will be passed to the
  process as is, without a shell transforming them, They don't need to
  be escaped.

- `stdin`:

  What to do with the standard input. Possible values:

  - `NULL`: set to the *null device*, i.e. no standard input is
    provided;

  - a file name, use this file as standard input;

  - `"|"`: create a (writeable) connection for stdin.

  - `""` (empty string): inherit it from the main R process. If the main
    R process does not have a standard input stream, e.g. in RGui on
    Windows, then an error is thrown.

- `stdout`:

  What to do with the standard output. Possible values:

  - `NULL`: discard it;

  - A string starting with `">>"`, e.g. `">>output.txt"`: append it to
    this file. The file is created if it does not exist.

  - A string (not starting with `">>"`), redirect it to this file,
    truncating the file first. Note that if you specify a relative path,
    it will be relative to the current working directory, even if you
    specify another directory in the `wd` argument. (See issue 324.)

  - `"|"`: create a connection for it.

  - `""` (empty string): inherit it from the main R process. If the main
    R process does not have a standard output stream, e.g. in RGui on
    Windows, then an error is thrown.

- `stderr`:

  What to do with the standard error. Possible values:

  - `NULL`: discard it.

  - A string starting with `">>"`, e.g. `">>error.txt"`: append it to
    this file. The file is created if it does not exist.

  - A string (not starting with `">>"`), redirect it to this file,
    truncating the file first. Note that if you specify a relative path,
    it will be relative to the current working directory, even if you
    specify another directory in the `wd` argument. (See issue 324.)

  - `"|"`: create a connection for it.

  - `"2>&1"`: redirect it to the same connection (i.e. pipe or file) as
    `stdout`. `"2>&1"` is a way to keep standard output and error
    correctly interleaved.

  - `""` (empty string): inherit it from the main R process. If the main
    R process does not have a standard error stream, e.g. in RGui on
    Windows, then an error is thrown.

- `pty`:

  Whether to create a pseudo terminal (pty) for the background process.
  This is currently only supported on Unix systems, but not supported on
  Solaris. If it is `TRUE`, then the `stdin`, `stdout` and `stderr`
  arguments must be `NULL`. If a pseudo terminal is created, then
  processx will create pipes for standard input and standard output.
  There is no separate pipe for standard error, because there is no way
  to distinguish between stdout and stderr on a pty. Note that the
  standard output connection of the pty is *blocking*, so we always poll
  the standard output connection before reading from it using the
  `$read_output()` method. Also, because `$read_output_lines()` could
  still block if no complete line is available, this function always
  fails if the process has a pty. Use `$read_output()` to read from
  ptys.

- `pty_options`:

  Unix pseudo terminal options, a named list. see
  [`default_pty_options()`](http://processx.r-lib.org/dev/reference/default_pty_options.md)
  for details and defaults.

- `connections`:

  A list of processx connections to pass to the child process. This is
  an experimental feature currently.

- `poll_connection`:

  Whether to create an extra connection to the process that allows
  polling, even if the standard input and standard output are not pipes.
  If this is `NULL` (the default), then this connection will be only
  created if standard output and standard error are not pipes, and
  `connections` is an empty list. If the poll connection is created, you
  can query it via `p$get_poll_connection()` and it is also included in
  the response to `p$poll_io()` and
  [`poll()`](http://processx.r-lib.org/dev/reference/poll.md). The
  numeric file descriptor of the poll connection comes right after
  `stderr` (2), and the connections listed in `connections`.

- `env`:

  Environment variables of the child process. If `NULL`, the parent's
  environment is inherited. On Windows, many programs cannot function
  correctly if some environment variables are not set, so we always set
  `HOMEDRIVE`, `HOMEPATH`, `LOGONSERVER`, `PATH`, `SYSTEMDRIVE`,
  `SYSTEMROOT`, `TEMP`, `USERDOMAIN`, `USERNAME`, `USERPROFILE` and
  `WINDIR`. To append new environment variables to the ones set in the
  current process, specify `"current"` in `env`, without a name, and the
  appended ones with names. The appended ones can overwrite the current
  ones.

- `cleanup`:

  Whether to kill the process when the `process` object is garbage
  collected.

- `cleanup_tree`:

  Whether to kill the process and its child process tree when the
  `process` object is garbage collected.

- `wd`:

  Working directory of the process. It must exist. If `NULL`, then the
  current working directory is used.

- `echo_cmd`:

  Whether to print the command to the screen before running it.

- `supervise`:

  Whether to register the process with a supervisor. If `TRUE`, the
  supervisor will ensure that the process is killed when the R process
  exits.

- `windows_verbatim_args`:

  Whether to omit quoting the arguments on Windows. It is ignored on
  other platforms.

- `windows_hide_window`:

  Whether to hide the application's window on Windows. It is ignored on
  other platforms.

- `windows_detached_process`:

  Whether to use the `DETACHED_PROCESS` flag on Windows. If this is
  `TRUE`, then the child process will have no attached console, even if
  the parent had one.

- `encoding`:

  The encoding to assume for `stdin`, `stdout` and `stderr`. By default
  the encoding of the current locale is used. Note that `processx`
  always reencodes the output of the `stdout` and `stderr` streams in
  UTF-8 currently. If you want to read them without any conversion, on
  all platforms, specify `"UTF-8"` as encoding. Use `"binary"` to
  disable text conversion entirely: `$read_output()` and `$read_error()`
  will return raw vectors instead of character strings, preserving all
  bytes including null bytes and non-UTF-8 byte sequences.

- `post_process`:

  An optional function to run when the process has finished. Currently
  it only runs if `$get_result()` is called. It is only run once.

- `linux_pdeathsig`:

  On Linux, send this signal to the child process when the parent R
  process exits. `FALSE` (the default) disables this. `TRUE` sends
  `SIGTERM`. An integer signal number, e.g.
  [`tools::SIGTERM`](https://rdrr.io/r/tools/pskill.html) or
  [`tools::SIGKILL`](https://rdrr.io/r/tools/pskill.html), sends that
  signal. Ignored on non-Linux platforms.

#### Returns

R6 object representing the process.

------------------------------------------------------------------------

### Method `kill()`

Terminate the process. It also terminate all of its child processes,
except if they have created a new process group (on Unix), or job object
(on Windows). It returns `TRUE` if the process was terminated, and
`FALSE` if it was not (because it was already finished/dead when
`processx` tried to terminate it).

#### Usage

    process$kill(grace = 0.1, close_connections = TRUE)

#### Arguments

- `grace`:

  Currently not used.

- `close_connections`:

  Whether to close standard input, standard output, standard error
  connections and the poll connection, after killing the process.

------------------------------------------------------------------------

### Method `kill_tree()`

Process tree cleanup. It terminates the process (if still alive),
together with any child (or grandchild, etc.) processes. It uses the
*ps* package, so that needs to be installed, and *ps* needs to support
the current platform as well. Process tree cleanup works by marking the
process with an environment variable, which is inherited in all child
processes. This allows finding descendents, even if they are orphaned,
i.e. they are not connected to the root of the tree cleanup in the
process tree any more. `$kill_tree()` returns a named integer vector of
the process ids that were killed, the names are the names of the
processes (e.g. `"sleep"`, `"notepad.exe"`, `"Rterm.exe"`, etc.).

#### Usage

    process$kill_tree(grace = 0.1, close_connections = TRUE)

#### Arguments

- `grace`:

  Currently not used.

- `close_connections`:

  Whether to close standard input, standard output, standard error
  connections and the poll connection, after killing the process.

------------------------------------------------------------------------

### Method `signal()`

Send a signal to the process. On Windows only the `SIGINT`, `SIGTERM`
and `SIGKILL` signals are interpreted, and the special 0 signal. The
first three all kill the process. The 0 signal returns `TRUE` if the
process is alive, and `FALSE` otherwise. On Unix all signals are
supported that the OS supports, and the 0 signal as well.

#### Usage

    process$signal(signal)

#### Arguments

- `signal`:

  An integer scalar, the id of the signal to send to the process. See
  [`tools::pskill()`](https://rdrr.io/r/tools/pskill.html) for the list
  of signals.

------------------------------------------------------------------------

### Method `interrupt()`

Send an interrupt to the process. On Unix this is a `SIGINT` signal, and
it is usually equivalent to pressing CTRL+C at the terminal prompt. On
Windows, it is a CTRL+BREAK keypress. Applications may catch these
events. By default they will quit.

#### Usage

    process$interrupt()

------------------------------------------------------------------------

### Method `get_pid()`

Query the process id.

#### Usage

    process$get_pid()

#### Returns

Integer scalar, the process id of the process.

------------------------------------------------------------------------

### Method `is_alive()`

Check if the process is alive.

#### Usage

    process$is_alive()

#### Returns

Logical scalar.

------------------------------------------------------------------------

### Method `wait()`

Wait until the process finishes, or a timeout happens. Note that if the
process never finishes, and the timeout is infinite (the default), then
R will never regain control. In some rare cases, `$wait()` might take a
bit longer than specified to time out. This happens on Unix, when
another package overwrites the processx `SIGCHLD` signal handler, after
the processx process has started. One such package is parallel, if used
with fork clusters, e.g. through
[`parallel::mcparallel()`](https://rdrr.io/r/parallel/mcparallel.html).

#### Usage

    process$wait(timeout = -1)

#### Arguments

- `timeout`:

  Timeout in milliseconds, for the wait or the I/O polling.

#### Returns

It returns the process itself, invisibly.

------------------------------------------------------------------------

### Method `get_exit_status()`

`$get_exit_status` returns the exit code of the process if it has
finished and `NULL` otherwise. On Unix, in some rare cases, the exit
status might be `NA`. This happens if another package (or R itself)
overwrites the processx `SIGCHLD` handler, after the processx process
has started. In these cases processx cannot determine the real exit
status of the process. One such package is parallel, if used with fork
clusters, e.g. through the
[`parallel::mcparallel()`](https://rdrr.io/r/parallel/mcparallel.html)
function.

#### Usage

    process$get_exit_status()

------------------------------------------------------------------------

### Method [`format()`](https://rdrr.io/r/base/format.html)

`format(p)` or `p$format()` creates a string representation of the
process, usually for printing.

#### Usage

    process$format()

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

`print(p)` or `p$print()` shows some information about the process on
the screen, whether it is running and it's process id, etc.

#### Usage

    process$print()

------------------------------------------------------------------------

### Method `get_start_time()`

`$get_start_time()` returns the time when the process was started.

#### Usage

    process$get_start_time()

------------------------------------------------------------------------

### Method `get_end_time()`

`$get_end_time()` returns the time when the process finished, or `NULL`
if it is still running. On Unix the timestamp is recorded when R first
notices the exit (via the `SIGCHLD` handler or a call to `$is_alive()`,
`$get_exit_status()`, or `$wait()`), so it may be slightly later than
the actual kernel exit time. On Windows the exact kernel exit time is
used.

#### Usage

    process$get_end_time()

------------------------------------------------------------------------

### Method `is_supervised()`

`$is_supervised()` returns whether the process is being tracked by
supervisor process.

#### Usage

    process$is_supervised()

------------------------------------------------------------------------

### Method `supervise()`

`$supervise()` if passed `TRUE`, tells the supervisor to start tracking
the process. If `FALSE`, tells the supervisor to stop tracking the
process. Note that even if the supervisor is disabled for a process, if
it was started with `cleanup = TRUE`, the process will still be killed
when the object is garbage collected.

#### Usage

    process$supervise(status)

#### Arguments

- `status`:

  Whether to turn on of off the supervisor for this process.

------------------------------------------------------------------------

### Method `read_output()`

`$read_output()` reads from the standard output connection of the
process. If the standard output connection was not requested, then then
it returns an error. It uses a non-blocking text connection. This will
work only if `stdout="|"` was used. Otherwise, it will throw an error.
When the process was started with `encoding = "binary"`, returns a raw
vector instead of a character string.

A single call may return less data than requested (or an empty string)
even when more output will eventually arrive: the OS pipe buffer is
finite, and `$read_output()` only returns what is already buffered.
Always call `$poll_io()` (or
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md)) before
reading to avoid deadlocking when the child fills the pipe buffer (see
the *Polling* section for details). To read *all* output call
`$read_all_output()`.

#### Usage

    process$read_output(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `read_error()`

`$read_error()` is similar to `$read_output()`, but reads from the
standard error stream. Returns a raw vector when `encoding = "binary"`
was used. The same polling requirement applies as for `$read_output()`
(see the *Polling* section).

#### Usage

    process$read_error(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `read_output_bytes()`

`$read_output_bytes()` reads from the standard output connection of the
process and returns the result as a raw vector, preserving all bytes
including null bytes and other binary data. Switches the underlying
connection to raw mode; do not mix with `$read_output()`. This will work
only if `stdout="|"` was used.

#### Usage

    process$read_output_bytes(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `read_error_bytes()`

`$read_error_bytes()` is similar to `$read_output_bytes()`, but reads
from the standard error stream.

#### Usage

    process$read_error_bytes(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `read_output_lines()`

`$read_output_lines()` reads lines from standard output connection of
the process. If the standard output connection was not requested, then
it returns an error. It uses a non-blocking text connection. This will
work only if `stdout="|"` was used. Otherwise, it will throw an error.

Because `$read_output_lines()` only returns complete lines already in
the buffer, it may return zero lines even when the process has produced
output — for example when a line is longer than the pipe buffer (~64KB
on Linux/macOS, ~76KB on Windows) or when the line is not yet
terminated. Always call `$poll_io()` before reading to avoid deadlocking
(see the *Polling* section), and use `$read_output()` when lines may be
very long.

#### Usage

    process$read_output_lines(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `read_error_lines()`

`$read_error_lines()` is similar to `$read_output_lines`, but it reads
from the standard error stream. The same polling requirement applies
(see the *Polling* section).

#### Usage

    process$read_error_lines(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read.

------------------------------------------------------------------------

### Method `is_incomplete_output()`

`$is_incomplete_output()` return `FALSE` if the other end of the
standard output connection was closed (most probably because the process
exited). It return `TRUE` otherwise.

#### Usage

    process$is_incomplete_output()

------------------------------------------------------------------------

### Method `is_incomplete_error()`

`$is_incomplete_error()` return `FALSE` if the other end of the standard
error connection was closed (most probably because the process exited).
It return `TRUE` otherwise.

#### Usage

    process$is_incomplete_error()

------------------------------------------------------------------------

### Method `has_input_connection()`

`$has_input_connection()` return `TRUE` if there is a connection object
for standard input; in other words, if `stdout="|"`. It returns `FALSE`
otherwise.

#### Usage

    process$has_input_connection()

------------------------------------------------------------------------

### Method `has_output_connection()`

`$has_output_connection()` returns `TRUE` if there is a connection
object for standard output; in other words, if `stdout="|"`. It returns
`FALSE` otherwise.

#### Usage

    process$has_output_connection()

------------------------------------------------------------------------

### Method `has_error_connection()`

`$has_error_connection()` returns `TRUE` if there is a connection object
for standard error; in other words, if `stderr="|"`. It returns `FALSE`
otherwise.

#### Usage

    process$has_error_connection()

------------------------------------------------------------------------

### Method `has_poll_connection()`

`$has_poll_connection()` return `TRUE` if there is a poll connection,
`FALSE` otherwise.

#### Usage

    process$has_poll_connection()

------------------------------------------------------------------------

### Method `get_input_connection()`

`$get_input_connection()` returns a connection object, to the standard
input stream of the process.

#### Usage

    process$get_input_connection()

------------------------------------------------------------------------

### Method `get_output_connection()`

`$get_output_connection()` returns a connection object, to the standard
output stream of the process.

#### Usage

    process$get_output_connection()

------------------------------------------------------------------------

### Method `get_error_connection()`

`$get_error_conneciton()` returns a connection object, to the standard
error stream of the process.

#### Usage

    process$get_error_connection()

------------------------------------------------------------------------

### Method `read_all_output()`

`$read_all_output()` waits for all standard output from the process. It
does not return until the process has finished. Note that this process
involves waiting for the process to finish, polling for I/O and
potentially several
[`readLines()`](https://rdrr.io/r/base/readLines.html) calls. It returns
a character scalar. This will return content only if `stdout="|"` was
used. Otherwise, it will throw an error.

#### Usage

    process$read_all_output()

------------------------------------------------------------------------

### Method `read_all_error()`

`$read_all_error()` waits for all standard error from the process. It
does not return until the process has finished. Note that this process
involves waiting for the process to finish, polling for I/O and
potentially several
[`readLines()`](https://rdrr.io/r/base/readLines.html) calls. It returns
a character scalar. This will return content only if `stderr="|"` was
used. Otherwise, it will throw an error.

#### Usage

    process$read_all_error()

------------------------------------------------------------------------

### Method `read_all_output_lines()`

`$read_all_output_lines()` waits for all standard output lines from a
process. It does not return until the process has finished. Note that
this process involves waiting for the process to finish, polling for I/O
and potentially several
[`readLines()`](https://rdrr.io/r/base/readLines.html) calls. It returns
a character vector. This will return content only if `stdout="|"` was
used. Otherwise, it will throw an error.

#### Usage

    process$read_all_output_lines()

------------------------------------------------------------------------

### Method `read_all_error_lines()`

`$read_all_error_lines()` waits for all standard error lines from a
process. It does not return until the process has finished. Note that
this process involves waiting for the process to finish, polling for I/O
and potentially several
[`readLines()`](https://rdrr.io/r/base/readLines.html) calls. It returns
a character vector. This will return content only if `stderr="|"` was
used. Otherwise, it will throw an error.

#### Usage

    process$read_all_error_lines()

------------------------------------------------------------------------

### Method `write_input()`

`$write_input()` writes the character vector (separated by `sep`) to the
standard input of the process. It will be converted to the specified
encoding. This operation is non-blocking, and it will return, even if
the write fails (because the write buffer is full), or if it suceeds
partially (i.e. not the full string is written). It returns with a raw
vector, that contains the bytes that were not written. You can supply
this raw vector to `$write_input()` again, until it is fully written,
and then the return value will be `raw(0)` (invisibly).

#### Usage

    process$write_input(str, sep = "\n")

#### Arguments

- `str`:

  Character or raw vector to write to the standard input of the process.
  If a character vector with a marked encoding, it will be converted to
  `encoding`.

- `sep`:

  Separator to add between `str` elements if it is a character vector.
  It is ignored if `str` is a raw vector.

#### Returns

Leftover text (as a raw vector), that was not written.

------------------------------------------------------------------------

### Method `get_input_file()`

`$get_input_file()` if the `stdin` argument was a filename, this returns
the absolute path to the file. If `stdin` was `"|"` or `NULL`, this
simply returns that value.

#### Usage

    process$get_input_file()

------------------------------------------------------------------------

### Method `get_output_file()`

`$get_output_file()` if the `stdout` argument was a filename, this
returns the absolute path to the file. If `stdout` was `"|"` or `NULL`,
this simply returns that value.

#### Usage

    process$get_output_file()

------------------------------------------------------------------------

### Method `get_error_file()`

`$get_error_file()` if the `stderr` argument was a filename, this
returns the absolute path to the file. If `stderr` was `"|"` or `NULL`,
this simply returns that value.

#### Usage

    process$get_error_file()

------------------------------------------------------------------------

### Method `poll_io()`

`$poll_io()` polls the process's connections for I/O. See more in the
*Polling* section, and see also the
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md) function to
poll on multiple processes.

#### Usage

    process$poll_io(timeout)

#### Arguments

- `timeout`:

  Timeout in milliseconds, for the wait or the I/O polling.

------------------------------------------------------------------------

### Method `get_poll_connection()`

`$get_poll_connetion()` returns the poll connection, if the process has
one.

#### Usage

    process$get_poll_connection()

------------------------------------------------------------------------

### Method `get_result()`

`$get_result()` returns the result of the post processesing function. It
can only be called once the process has finished. If the process has no
post-processing function, then `NULL` is returned.

#### Usage

    process$get_result()

------------------------------------------------------------------------

### Method `as_ps_handle()`

`$as_ps_handle()` returns a
[ps::ps_handle](https://ps.r-lib.org/reference/ps_handle.html) object,
corresponding to the process.

#### Usage

    process$as_ps_handle()

------------------------------------------------------------------------

### Method `get_name()`

Calls [`ps::ps_name()`](https://ps.r-lib.org/reference/ps_name.html) to
get the process name.

#### Usage

    process$get_name()

------------------------------------------------------------------------

### Method `get_exe()`

Calls [`ps::ps_exe()`](https://ps.r-lib.org/reference/ps_exe.html) to
get the path of the executable.

#### Usage

    process$get_exe()

------------------------------------------------------------------------

### Method `get_cmdline()`

Calls
[`ps::ps_cmdline()`](https://ps.r-lib.org/reference/ps_cmdline.html) to
get the command line.

#### Usage

    process$get_cmdline()

------------------------------------------------------------------------

### Method `get_status()`

Calls [`ps::ps_status()`](https://ps.r-lib.org/reference/ps_status.html)
to get the process status.

#### Usage

    process$get_status()

------------------------------------------------------------------------

### Method `get_username()`

calls
[`ps::ps_username()`](https://ps.r-lib.org/reference/ps_username.html)
to get the username.

#### Usage

    process$get_username()

------------------------------------------------------------------------

### Method `get_wd()`

Calls [`ps::ps_cwd()`](https://ps.r-lib.org/reference/ps_cwd.html) to
get the current working directory.

#### Usage

    process$get_wd()

------------------------------------------------------------------------

### Method `get_cpu_times()`

Calls
[`ps::ps_cpu_times()`](https://ps.r-lib.org/reference/ps_cpu_times.html)
to get CPU usage data.

#### Usage

    process$get_cpu_times()

------------------------------------------------------------------------

### Method `get_memory_info()`

Calls
[`ps::ps_memory_info()`](https://ps.r-lib.org/reference/ps_memory_info.html)
to get memory data.

#### Usage

    process$get_memory_info()

------------------------------------------------------------------------

### Method `suspend()`

Calls
[`ps::ps_suspend()`](https://ps.r-lib.org/reference/ps_suspend.html) to
suspend the process.

#### Usage

    process$suspend()

------------------------------------------------------------------------

### Method `resume()`

Calls [`ps::ps_resume()`](https://ps.r-lib.org/reference/ps_resume.html)
to resume a suspended process.

#### Usage

    process$resume()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    process$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
p <- process$new("sleep", "2")
p$is_alive()
#> [1] TRUE
p
#> PROCESS 'sleep', running, pid 7064.
p$kill()
#> [1] TRUE
p$is_alive()
#> [1] FALSE

p <- process$new("sleep", "1")
p$is_alive()
#> [1] TRUE
Sys.sleep(2)
p$is_alive()
#> [1] FALSE
```
