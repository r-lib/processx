# Pipeline of processes connected with pipes

**\[experimental\]**

A `pipeline` object represents a sequence of processes whose standard
input and output streams are connected with pipes, like a Unix pipeline
(`cmd1 | cmd2 | cmd3`). Data flows directly between the child processes
via kernel-level pipes — the parent R process sees only the output of
the final command (when `stdout = "|"`).

## Methods

`pipeline$new(cmds, stdin, stdout, stderr, env, encoding, wd, cleanup, cleanup_tree)`

`$read_output(n = -1)`, `$read_output_lines(n = -1)`,
`$read_all_output()`, `$read_all_output_lines()` — read from the last
process (only meaningful when `stdout = "|"`).

`$poll_io(timeout)` — poll the last process's connections for I/O.

`$read_error(n = -1)`, `$read_error_lines(n = -1)`, `$read_all_error()`,
`$read_all_error_lines()` — read stderr of the last process (only
meaningful when `stderr = "|"`).

`$write_input(str, sep = "\n")` — write to first process stdin (only
meaningful when `stdin = "|"`).

`$close_input()` — close the first process stdin, signalling EOF.

`$wait(timeout = -1)` — wait for all processes to finish.

`$kill(grace = 0.1, close_connections = TRUE)` — kill all processes.

`$kill_tree(grace = 0.1, close_connections = TRUE)` — kill all process
trees.

`$is_alive()` — returns `TRUE` if any process is still running.

`$get_exit_statuses()` — list of exit codes (one per process; `NULL` if
still running).

`$get_pids()` — integer vector of process IDs.

`$get_processes()` — list of
[process](http://processx.r-lib.org/dev/reference/process.md) objects,
one per command.

`$format()` — string representation of the pipeline.

`$print()` — print the pipeline to the screen.

## Methods

### Public methods

- [`pipeline$new()`](#method-pipeline-new)

- [`pipeline$read_output()`](#method-pipeline-read_output)

- [`pipeline$read_output_lines()`](#method-pipeline-read_output_lines)

- [`pipeline$read_all_output()`](#method-pipeline-read_all_output)

- [`pipeline$read_all_output_lines()`](#method-pipeline-read_all_output_lines)

- [`pipeline$poll_io()`](#method-pipeline-poll_io)

- [`pipeline$read_error()`](#method-pipeline-read_error)

- [`pipeline$read_error_lines()`](#method-pipeline-read_error_lines)

- [`pipeline$read_all_error()`](#method-pipeline-read_all_error)

- [`pipeline$read_all_error_lines()`](#method-pipeline-read_all_error_lines)

- [`pipeline$write_input()`](#method-pipeline-write_input)

- [`pipeline$close_input()`](#method-pipeline-close_input)

- [`pipeline$wait()`](#method-pipeline-wait)

- [`pipeline$kill()`](#method-pipeline-kill)

- [`pipeline$kill_tree()`](#method-pipeline-kill_tree)

- [`pipeline$is_alive()`](#method-pipeline-is_alive)

- [`pipeline$get_exit_statuses()`](#method-pipeline-get_exit_statuses)

- [`pipeline$get_pids()`](#method-pipeline-get_pids)

- [`pipeline$get_processes()`](#method-pipeline-get_processes)

- [`pipeline$format()`](#method-pipeline-format)

- [`pipeline$print()`](#method-pipeline-print)

------------------------------------------------------------------------

### Method `new()`

Create a new pipeline.

#### Usage

    pipeline$new(
      cmds,
      stdin = NULL,
      stdout = "|",
      stderr = NULL,
      env = NULL,
      encoding = "utf-8",
      wd = NULL,
      cleanup = TRUE,
      cleanup_tree = FALSE
    )

#### Arguments

- `cmds`:

  A non-empty list of character vectors. Each vector is one command: the
  first element is the executable and the rest are its arguments.
  Example: `list(c("sort"), c("uniq", "-c"))`.

- `stdin`:

  Standard input for the *first* process. `NULL` to discard, `"|"` so
  the parent R process can write to it via `$write_input()`, or a file
  path.

- `stdout`:

  Standard output of the *last* process. `"|"` (the default) so the
  parent R process can read from it, `NULL` to discard, or a file path.

- `stderr`:

  Standard error for *all* processes. `NULL` (the default) to discard,
  `"|"` to create a separate readable pipe per process, `"2>&1"` to
  merge into stdout, or a file path. When `"|"`, use `$read_error()` to
  read from the last process; use `$get_processes()` to access
  individual process objects for other processes.

- `env`:

  Environment variables for all processes, or `NULL` to inherit the
  parent environment.

- `encoding`:

  Assumed encoding for stdin/stdout/stderr streams.

- `wd`:

  Working directory for all processes, or `NULL` for the current
  directory.

- `cleanup`:

  Whether to kill the processes on garbage collection.

- `cleanup_tree`:

  Whether to kill the full process trees on garbage collection.

------------------------------------------------------------------------

### Method `read_output()`

Read output of the last process.

#### Usage

    pipeline$read_output(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read. -1 means all available.

------------------------------------------------------------------------

### Method `read_output_lines()`

Read output lines of the last process.

#### Usage

    pipeline$read_output_lines(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read. -1 means all available.

------------------------------------------------------------------------

### Method `read_all_output()`

Read all output of the last process.

#### Usage

    pipeline$read_all_output()

------------------------------------------------------------------------

### Method `read_all_output_lines()`

Read all output lines of the last process.

#### Usage

    pipeline$read_all_output_lines()

------------------------------------------------------------------------

### Method `poll_io()`

Poll the connections of the last process for I/O.

#### Usage

    pipeline$poll_io(timeout)

#### Arguments

- `timeout`:

  Timeout in milliseconds. -1 means no timeout.

------------------------------------------------------------------------

### Method `read_error()`

Read stderr of the last process.

#### Usage

    pipeline$read_error(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read. -1 means all available.

------------------------------------------------------------------------

### Method `read_error_lines()`

Read stderr lines of the last process.

#### Usage

    pipeline$read_error_lines(n = -1)

#### Arguments

- `n`:

  Number of characters or lines to read. -1 means all available.

------------------------------------------------------------------------

### Method `read_all_error()`

Read all stderr of the last process.

#### Usage

    pipeline$read_all_error()

------------------------------------------------------------------------

### Method `read_all_error_lines()`

Read all stderr lines of the last process.

#### Usage

    pipeline$read_all_error_lines()

------------------------------------------------------------------------

### Method `write_input()`

Write to the first process stdin.

#### Usage

    pipeline$write_input(str, sep = "\n")

#### Arguments

- `str`:

  String to write to the process stdin.

- `sep`:

  Separator to add after `str`.

------------------------------------------------------------------------

### Method `close_input()`

Close the first process stdin (signals EOF to the process).

#### Usage

    pipeline$close_input()

------------------------------------------------------------------------

### Method `wait()`

Wait for all processes to finish.

#### Usage

    pipeline$wait(timeout = -1)

#### Arguments

- `timeout`:

  Timeout in milliseconds. -1 means no timeout.

------------------------------------------------------------------------

### Method `kill()`

Kill all processes.

#### Usage

    pipeline$kill(grace = 0.1, close_connections = TRUE)

#### Arguments

- `grace`:

  Grace period in seconds before sending SIGKILL (Unix) or terminating
  forcefully (Windows). Currently not used.

- `close_connections`:

  Whether to close connections after killing.

------------------------------------------------------------------------

### Method `kill_tree()`

Kill all process trees.

#### Usage

    pipeline$kill_tree(grace = 0.1, close_connections = TRUE)

#### Arguments

- `grace`:

  Grace period in seconds before sending SIGKILL (Unix) or terminating
  forcefully (Windows). Currently not used.

- `close_connections`:

  Whether to close connections after killing.

------------------------------------------------------------------------

### Method `is_alive()`

Check if any process is still alive.

#### Usage

    pipeline$is_alive()

------------------------------------------------------------------------

### Method `get_exit_statuses()`

Return exit codes for all processes.

#### Usage

    pipeline$get_exit_statuses()

------------------------------------------------------------------------

### Method `get_pids()`

Return PIDs for all processes.

#### Usage

    pipeline$get_pids()

------------------------------------------------------------------------

### Method `get_processes()`

Return the list of process objects.

#### Usage

    pipeline$get_processes()

------------------------------------------------------------------------

### Method [`format()`](https://rdrr.io/r/base/format.html)

Format the pipeline as a string.

#### Usage

    pipeline$format()

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print the pipeline to the screen.

#### Usage

    pipeline$print(...)

#### Arguments

- `...`:

  Not used, for compatibility with the generic.

## Examples

``` r
if (FALSE) { # \dontrun{
# sort | uniq, reading from / writing to R
pl <- pipeline$new(
  list(c("sort"), c("uniq")),
  stdin = "|", stdout = "|"
)
pl$write_input("b\na\nb\na\n")
pl$close_input()
pl$read_all_output_lines()
pl$wait()
pl$get_exit_statuses()
} # }
```
