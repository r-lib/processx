# Terminate all supervised processes and the supervisor process itself as well

On Unix the supervisor sends a `SIGTERM` signal to all supervised
processes, and gives them five seconds to quit, before sending a
`SIGKILL` signal. Then the supervisor itself terminates.

## Usage

``` r
supervisor_kill()
```

## Details

Windows is similar, but instead of `SIGTERM`, a console CTRL+C interrupt
is sent first, then a `WM_CLOSE` message is sent to the windows of the
supervised processes, if they have windows.
