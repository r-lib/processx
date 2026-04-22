# Start a process

Start a process

## Usage

``` r
process_initialize(
  self,
  private,
  command,
  args,
  stdin,
  stdout,
  stderr,
  pty,
  pty_options,
  connections,
  poll_connection,
  env,
  cleanup,
  cleanup_tree,
  wd,
  echo_cmd,
  supervise,
  windows_verbatim_args,
  windows_hide_window,
  windows_detached_process,
  encoding,
  post_process,
  linux_pdeathsig
)
```

## Arguments

- self:

  this

- private:

  this\$private

- command:

  Command to run, string scalar.

- args:

  Command arguments, character vector.

- stdin:

  Standard input, NULL to ignore.

- stdout:

  Standard output, NULL to ignore, TRUE for temp file.

- stderr:

  Standard error, NULL to ignore, TRUE for temp file.

- pty:

  Whether we create a PTY.

- connections:

  Connections to inherit in the child process.

- poll_connection:

  Whether to create a connection for polling.

- env:

  Environment vaiables.

- cleanup:

  Kill on GC?

- cleanup_tree:

  Kill process tree on GC?

- wd:

  working directory (or NULL)

- echo_cmd:

  Echo command before starting it?

- supervise:

  Should the process be supervised?

- encoding:

  Assumed stdout and stderr encoding.

- post_process:

  Post processing function.
