
# `processx` internals

## Introduction

If you are interested in how a specific function works, make sure that you
read the source code as well, as some details are not documented in this
writeup

## Unix

### Process startup

We use a pipe to detect startup errors. The pipe is set up with the
`CLOEXEC` (close on exec) flag, so if the `exec()` call fails, then it
is *not* closed, and the parent can detect this by trying to read from the
pipe. If the `exec()` call fails, then the child will send the error code
over the pipe.

The child process closes all file descriptors above 3, because they
can cause hangs in RStudio and elsewhere.
See https://github.com/r-pkgs/processx/issues/52

### The handle

The handle is not that interesting. It has these members:
```
typedef struct processx_handle_s {
  int exitcode;
  int collected;	 /* Whether exit code was collected already */
  pid_t pid;
  int fd0;			/* writeable */
  int fd1;			/* readable */
  int fd2;			/* readable */
  char tails[3];
  int waitpipe[2];		/* use it for wait() with timeout */
  int cleanup;
} processx_handle_t;
```

The exit code can be collected at various times, a lot of functions can
trigger the collection as a side effect, e.g. `kill`, `signal`, etc.

The fds for standard I/O are currently hardcoded here. `tails` is a
character for each fd (not needed for stdin, but easier to index this way).
This is the last character we read from the pipe. We need this, because
R is very bad in reading a last line that does not end with a newline,
if the connection is non-blocking. So we add an artificial `\n` to the
end of the file, if the true last character was not a `\n`. That's why we
need to keep the last character.

The handle is freed in the finalizer.

### The child list

We need to keep a list of processes that were started by us. This is
because R and other packages also start child processes, and we get
SIGCHLD signals for them, but we don't want to deal with them, only with
our own children. So we need to know our own child processes.

This is a single linked list with a HEAD element. We add the child process
to it when it starts, and remove it in the SIGCHLD handler. One tricky
thing here is that when we remove the node from the list, we cannot free
its memory, because it is not allowed to call free from a signal handler,
as malloc/free are not reentrant. So when we remove a node, we add it to
the free list, and we deallocate the free-list nodes later, e.g. in the
finalizer.

### SIGCHLD handler

The SIGCHLD handler is fairly simple, it only has one complication.
In theory the handler callback receives the PID of the process sending the
SIGCHLD in the `siginfo_t` argument, but in practice this is useless.
The system might throttle signals, and deliver a single signal for multiple
SIGCHLD events, even if they were triggered by different (child) processes.
(Yes, a single child process might trigger multiple SIGCHLD signals as well,
if it is stopped and then continued with SIGSTOP and SIGCONT signals.)

Anyway, so if this happens (and it does happen in practice), then we don't
get the pids of all child processes that exited. So for every SIGCHLD, we
need to iterate over our child process list, and call a `waitpid()` on the
child, to see if it has exited.

A process can have only a single SIGCHLD handler, it is in practice
impossible to chain them. This is mostly fine, as R usually does not care
about SIGCHLD, except for the fork type clusters in the `parallel` package.
This package defines its own SIGCHLD handler, which removes the one
installed by `processx`. This means that `processx` cannot be used
together with `parallel` fork clusters. We will probably improve this
later, see https://github.com/r-pkgs/processx/issues/45

### Finalizer

The finalizer takes care of killing the child process if its associated
handle goes out of scope. (Unless the process was started with
`cleanup = FALSE`. In that case it just frees the memory.)

Note that the finalizer is sometimes called before the SIGCHLD handler,
e.g. when cleaning up a running child process because the associated R
object is garbage collected. Then the finalizer kills the process first.
In other cases it is called after the SIGCHLD handler, e.g. when the
process has already finished, but its associated R object still exists.

In the latter case the exit status might have been collected already,
or not. If not, the finalizer collects it.

The finalizer needs to free the handle, it is the finalizer of the
external pointer handle object, after all. But we still want to have some
information about the process, e.g. its pid and its exit status. So the
finalizer copies these over into the `private` environment of the R6
`process` object. The `private` environment is passed around as the tag of
the external pointer.

### I/O

We currently attach `/dev/null` to the child process's standard input.
This is good, because if the child read from the standard input, the
read calls return immediately with no result. In the future we might have
a pipe to stdin, but then we'll need to worry about deadlock. (I.e. child
waits for parent, parent waits for child.)

#### Pipes

We either redirect standard output and error to files, or build pipes to
them. The pipes are non-blocking.

#### Connections

For the pipes we create non-blocking R connections. These connection objects
are independent of the process object, in that they are kept alive after the
connections finalized. This is because the pipe buffers might still contain
data. This also means that users must be careful when trying to read out
all remaining data from the pipes. We provide some simple wrappers that
help with this.

One tricky thing about non-blocking R connections, is that they have
trouble representing the state when all data is read out, but there was no
newline character at the end of the file. So we keep track of the last
character in the file, and when there is no more data, we artificially
insert it into the stream.

We make the connections have class `textConnection` because these do not
print any warnings to the screen when they are closed on garbage collection.

### Waiting with a timeout

There is no Unix primitive to wait on process with a timeout. To create a
pollable event, we create a pipe that we poll for reading. In the SIGCHLD
handler, that is called when the child finishes, we close this pipe, so the
poll event kicks in.

### Interruptible polling and waiting

It is important for the user experience that we make all polls and waits
interruptible. To simplify this, we implement all polls and waits by
polling for short time intervals, and then calling `R_CheckUserInterrupt()`.
This call might long jump, so we have to make sure that all temporary
allocations use R's allocators, and not just `malloc` etc., to avoid memory
leaks.

### Unloading the package

Unloading the package kills all processes (except for the ones started via
`cleanup = FALSE`). This is necessary as the data structures that are used
to deal with them are not available any more.

## Windows
