# Process cleanup

## Introduction

When you start a subprocess with processx, the subprocess may outlive
the R session — or even your function call — unless you explicitly take
care of cleanup. This article describes the five mechanisms processx
provides for cleaning up background processes and process trees, and
explains how each one works internally on Unix and Windows.

The mechanisms, from simplest to most powerful, are:

1.  Explicit cleanup with
    [`on.exit()`](https://rdrr.io/r/base/on.exit.html) — always works,
    fully deterministic.
2.  Automatic cleanup on garbage collection (`cleanup = TRUE`, the
    default).
3.  Process-tree cleanup (`cleanup_tree = TRUE`).
4.  Linux parent-death signal (`linux_pdeathsig`) — Linux only, handles
    R crashes.
5.  Supervisor process (`supervise = TRUE`) — all platforms, handles R
    crashes.

## Explicit cleanup with `on.exit()`

The most reliable pattern is to register cleanup in an
[`on.exit()`](https://rdrr.io/r/base/on.exit.html) call right after
starting the process. This runs when the enclosing function exits,
whether normally, on error, or on interrupt:

``` r
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
```

If you interrupt `process_manager()` or an error is thrown, both `p1`
and `p2` are killed immediately. Their connections are also closed.

Use `$kill_tree()` instead of `$kill()` if the subprocesses themselves
start child processes that should also be cleaned up.

## Automatic cleanup on garbage collection (`cleanup = TRUE`)

By default, `cleanup = TRUE` is set when you create a process. When the
`process` R object is garbage collected, processx kills the underlying
subprocess.

### Unix

On Unix, the child process calls `setsid()` immediately after `fork()`,
which creates a new session and makes the child the leader of a new
process group. When the garbage collector finalizes the `process`
object, processx calls `kill(-pid, SIGKILL)` — sending `SIGKILL` to the
*negative* PID kills every process in the child’s process group, not
just the child itself. This means direct subprocesses started by the
child (that have not called `setsid()` themselves) are also killed.

Note that a processx subprocess that itself starts further processx
subprocesses will call `setsid()` too, so each processx process is in
its own process group. `kill(-pid, SIGKILL)` will therefore *not* reach
processx grandchildren.

### Windows

On Windows, when the first processx subprocess with `cleanup = TRUE` is
started, processx creates a global [Job
Object](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)
configured with:

- `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`: all processes in the job are
  killed when the job handle is closed.
- `JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK`: child processes started by the
  job’s members are *not* automatically added to the job.

Every subprocess with `cleanup = TRUE` is added to this job object. When
R exits — including after a crash — the job handle is closed and all
contained subprocesses are killed automatically by the kernel. The
garbage-collector finalizer also calls `TerminateProcess()` for
individual cleanup when a `process` object is collected.

### Limitations

- GC timing is non-deterministic. If you need the subprocess to be
  killed at a predictable time, use
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html) instead.
- On Unix, `cleanup = TRUE` does not help if R itself crashes: the C
  finalizer will not run. See the supervisor section below for
  crash-safe cleanup on Unix.

## Process tree cleanup (`cleanup_tree = TRUE`)

`cleanup_tree = TRUE` extends cleanup to the entire *process tree*
rooted at the subprocess — including grandchildren, great-grandchildren,
and so on — even if those descendant processes have been orphaned
(reparented to PID 1 on Unix).

### How it works

At startup, processx generates a random *tree ID* and passes it to the
child via an environment variable:

    PROCESSX_<tree_id>=YES

Because environment variables are inherited across `exec()` and
`fork()`, every descendant process carries this variable, regardless of
how deep the tree goes or whether any intermediate ancestor has already
exited.

When `$kill_tree()` is called (or when the `process` object is garbage
collected with `cleanup_tree = TRUE`), processx delegates to
[`ps::ps_kill_tree()`](https://ps.r-lib.org/reference/ps_kill_tree.html),
which scans all running processes on the system, finds those carrying
the marker environment variable, and kills them.

`cleanup_tree = TRUE` implies `cleanup = TRUE`.

### Requirements

Tree cleanup requires the [ps](https://ps.r-lib.org) package and
[`ps::ps_is_supported()`](https://ps.r-lib.org/reference/ps_os_type.html)
must return `TRUE`.

### macOS caveat

On macOS, System Integrity Protection (SIP) and related kernel
restrictions may prevent reading the environment variables of other
processes. If that is the case, `$kill_tree()` and `cleanup_tree = TRUE`
may silently fail to find and kill descendants. Do not rely on
process-tree cleanup being fully reliable on macOS. Use the supervisor
(see below) if you need crash-safe or reliable tree cleanup on macOS.

## Linux parent-death signal (`linux_pdeathsig`)

On Linux, you can ask the kernel to automatically send a signal to the
child process when the parent R process dies — including if R crashes:

``` r
p <- process$new("sleep", "100", linux_pdeathsig = TRUE)
```

### How it works

The child process calls `prctl(PR_SET_PDEATHSIG, signal)` immediately
after `setsid()`. This is a Linux kernel feature: the kernel will
deliver the specified signal to the process when its parent (the R
process) exits, for any reason.

- `linux_pdeathsig = FALSE` (default): disabled.
- `linux_pdeathsig = TRUE`: sends `SIGTERM` when the parent dies.
- `linux_pdeathsig = tools::SIGKILL` (or any positive integer signal
  number): sends that signal.

processx also unblocks the death signal in the child after calling
`prctl()`, in case the signal was blocked at `fork()` time (some
sanitizer runtimes temporarily block signals during fork).

### Limitations

- **Linux only.** On other platforms (macOS, Windows) the argument is
  accepted but ignored (with a warning).
- Only the direct child receives the signal. Grandchildren are not
  affected unless they also use `linux_pdeathsig`.

### When to use it

`linux_pdeathsig` is the most reliable cleanup-on-crash mechanism on
Linux. It is kernel-enforced, has zero runtime overhead, and requires no
external process. Use it whenever you need cleanup to happen even if R
crashes, and you are on Linux.

## Supervisor process (`supervise = TRUE`)

The supervisor is a separate native executable (`supervisor.exe` on
Windows, `supervisor` on Unix) that processx ships alongside itself.
When `supervise = TRUE` is set, the supervisor process is started and
the child PID is registered with it. The supervisor polls every 200 ms
to check whether the parent R process is still running; if the parent
has died (for any reason, including a crash), the supervisor kills all
registered children.

``` r
p <- process$new("sleep", "100", supervise = TRUE)
```

### Unix behavior

The supervisor sends `SIGTERM` to each registered child. It then waits
up to 5 seconds. Any child still running after the grace period receives
`SIGKILL`.

### Windows behavior

The supervisor sends a CTRL+C event and a `WM_CLOSE` message to each
registered child. It then waits up to 5 seconds. Any child still running
after the grace period is hard-killed via `TerminateProcess()`.

### Windows Defender caveat

On Windows, `supervisor.exe` is a small standalone executable bundled
with the processx package. Windows Defender and other antivirus products
may flag, quarantine, or block it. If `supervise = TRUE` fails on
Windows or the supervisor does not start, check your antivirus software
and add an exclusion for the processx library path if necessary.

### When to use it

The supervisor is the only mechanism that is:

- crash-safe (handles R crashes), and
- cross-platform (works on Linux, macOS, and Windows).

Use it when you must guarantee cleanup after an R crash and you cannot
rely on the Linux-only `linux_pdeathsig`. The tradeoff is a small
background process and the Windows Defender risk.

## Summary

| Mechanism                                                                       | Platform              | Triggered by          | Scope                                  | Handles R crash?                                    |
|---------------------------------------------------------------------------------|-----------------------|-----------------------|----------------------------------------|-----------------------------------------------------|
| [`on.exit()`](https://rdrr.io/r/base/on.exit.html) + `$kill()` / `$kill_tree()` | all                   | explicit              | process group (Unix) or tree           | no                                                  |
| `cleanup = TRUE` (default)                                                      | all                   | GC / R exit           | process group (Unix); job object (Win) | Win: yes; Unix: no                                  |
| `cleanup_tree = TRUE`                                                           | Windows, Linux, macOS | GC                    | full descendant tree via env-var¹      | no                                                  |
| `linux_pdeathsig`                                                               | Linux only            | parent death (kernel) | direct child only                      | yes                                                 |
| `supervise = TRUE`                                                              | all                   | parent death          | registered PIDs                        | yes (unless antivirus blocks supervisor.exe on Win) |

¹ On macOS, system restrictions may prevent reading other processes’
environment variables, so tree cleanup may not work reliably there.

### Recommendations

- **General use:** rely on the default `cleanup = TRUE` and add
  `on.exit(p$kill())` for deterministic cleanup.
- **Need to clean the whole tree:** add `cleanup_tree = TRUE` and
  `on.exit(p$kill_tree())`. This requires the *ps* package and is
  currently only supported on Linux, Windows, and macOS. On macOS it may
  not work reliably due to system restrictions on reading other
  processes’ environment variables.
- **Linux, need crash safety:** use `linux_pdeathsig = TRUE` (or
  `= tools::SIGKILL`).
- **Cross-platform crash safety:** use `supervise = TRUE`. If you are a
  package developer using processx, consider exposing an option to let
  users disable the supervisor (e.g. via an option or environment
  variable). This gives Windows users a workaround if antivirus software
  blocks `supervisor.exe`.
