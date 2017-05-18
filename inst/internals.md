
# `processx` internals

* [Introduction](#introduction)
* [Unix](#unix)
   * [Process startup](#process-startup)
   * [The handle](#the-handle)
   * [The child list](#the-child-list)
   * [SIGCHLD handler](#sigchld-handler)
   * [Finalizer](#finalizer)
   * [I/O](#io)
      * [Pipes](#pipes)
      * [Connections](#connections)
   * [Waiting with a timeout](#waiting-with-a-timeout)
   * [Interruptible polling and waiting](#interruptible-polling-and-waiting)
   * [Unloading the package](#unloading-the-package)
* [Windows](#windows)
   * [Process startup](#process-startup-1)
   * [Job objects](#job-objects)
   * [Termination callbacks](#termination-callbacks)
   * [The handle](#the-handle-1)
   * [Finalizer](#finalizer-1)
   * [I/O](#io-1)
      * [Pipes](#pipes-1)
      * [Connections](#connections-1)
      * [Polling for I/O](#polling-for-io)
   * [Waiting with a timeout](#waiting-with-a-timeout-1)
   * [Interruptible polling and waiting](#interruptible-polling-and-waiting-1)
   * [Unloading the package](#unloading-the-package-1)

## Introduction

Read this document if you want to understand how parts of `processx` works.
You don't need to read it to *use* `processx`.

If you are interested in how a specific function works, make sure that you
read the source code as well, as some details are not documented in this
writeup.

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

```c
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

On Windows we use native Win32 API calls, instead of the partially
implemented POSIX wrappers.

### Process startup

We need to convert the program name and the arguments to utf16, so that we
can use `CreateProcessW` that works with Unicode file names and parameters.
The functions for this were ported from `libuv`.

Instead of relying on the Windows PATH search, we do our own search. This
was also ported from `libuv`. Our search handles spaces in the command
name or path better than the original Windows search that happens if we
just pass the whole command line to the Win32 API. E.g. we do not try to
call `c:\Program.exe` if the executable path includes `c:\Program Files`.

We start the process in suspended state, so we have time to assign it to
a job object, and also register a wait on the process handle.

Registering a wait is useful, because we get a callback call when the
process terminates.

One thing that is hard to get right is hiding the application and CMD
windows. We need to do this:
```c
  startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  startup.wShowWindow = options.windows_hide ? SW_HIDE : SW_SHOWDEFAULT;
```
and also use the `CREATE_NO_WINDOW` flag.

### Job objects

The job object is useful, because we can terminate all processes in the
same job object easily, and by default the child processes of the child
process will be in the same job object as the child process itself. This
also requires that the child process is *not* in the same job object as the
R process itself, so we start it with the `CREATE_BREAKAWAY_FROM_JOB` flag.

### Termination callbacks

The callback just collects the exit code of the process, the memory
deallocation happens in the finalizer.

### The handle

The windows process handle looks like this:

```c
typedef struct processx_handle_s {
  int exitcode;
  int collected;	 /* Whether exit code was collected already */
  HANDLE job;
  HANDLE hProcess;
  DWORD  dwProcessId;
  BYTE *child_stdio_buffer;
  HANDLE waitObject;
  processx_pipe_handle_t *pipes[3];
  int cleanup;
} processx_handle_t;
```
We only have `dwProcessId` to help the users manipulate the process without
`processx`, `processx` itself does everything based on the process handle.

The `child_stdio_buffer` is an undocumented way to pass data to the child
process. It is mostly copied from `libuv`. See this post for a good
explanation on how it works:
http://www.catch22.net/tuts/undocumented-createprocess#undoc
See also more on I/O below.

`waitObject` is the object we are waiting on for the termination of the
process.

The pipes are described below.

### Finalizer

The finalizer potentially kills the process. (All processes in the same
job object, actually.) This makes sure that the process is terminated when
its associated R object goes out of scope.

Then it copies over the pid and the exit code to R, so that these are
available after the process handle itself was cleaned up. We pass the
`private` environment of the `R6` object around, and copy over into that.

The finalizer also closes the process and job handles and deallocated
memory. It does *not* close the pipe handles, as there might still be data
in the pipe buffers.

### I/O

We use a `NUL` handle for standard input. This makes all read operations on
it finish immediately.

The standard output and error can be redirected to files or connected to
the parent process via pipes.

#### Pipes

We can use named pipes for standard output and error. The read ends of the
pipes, that are used in the parent, use overlapped I/O.

It is important that the pipe handles that are not used in the parent, are
closed. This is done by calling `processx__stdio_destroy`, as the last
step of the process startup. (The Windows documentation says that we should
not touch these handles in the parent, but actually that is not true, and
we need to explicitly close them, to avoid errors.)

On windows a pipe has a handle structure:

```c
typedef struct processx_pipe_handle_s {
  HANDLE pipe;
  OVERLAPPED overlapped;
  BYTE *buffer;
  DWORD buffer_size;
  BYTE *buffer_end;
  BOOLEAN read_pending;
  BOOLEAN EOF_signalled;
  char tail;
} processx_pipe_handle_t;
```

`overlapped` is reused for reading from the pipe. Note that reusing it
requires some caution. Before each `ReadFile`, we need to reset the `Offset`
and `OffsetHigh` members in it, overwise `ReadFile` might error out with
'Invalid Parameter':
```c
    handle->overlapped.Offset = 0;
    handle->overlapped.OffsetHigh = 0;
```

We use the event within `OVERLAPPED` to wait of the file operations, as
Windows documentation says that we cannot wait on the files handles
directly.

The `buffer`, `buffer_size` and `buffer_end` implement buffering and
will be probably eliminated in the future.
See https://github.com/r-pkgs/processx/issues/57

Here is the story for why we have buffering. For async reading from a file,
I mostly followed the example at
https://msdn.microsoft.com/en-us/library/windows/desktop/aa365690%28v=vs.85%29.aspx
The important part is this:
```c
        // Attempt an asynchronous read operation.
        bResult = ReadFile(hFile,
                           inBuffer,
                           nBytesToRead,
                           &dwBytesRead,
                           &stOverlapped);
[...]
        // Check for a problem or pending operation.
        if (!bResult)
        {
[...]
        }
        else
        {
            // EOF demo did not trigger for the given file.
            // Note that system caching may cause this condition on most files
            // after the first read. CreateFile can be called using the
            // FILE_FLAG_NOBUFFERING parameter but it would require reads are
            // always aligned to the volume's sector boundary. This is beyond
            // the scope of this example. See comments in the main() function.

            printf("ReadFile completed synchronously\n");
        }
```

This basically says that `ReadFile` *might* return synchronously, which
makes async I/O mightily inconvenient to program, if you want a `poll`-like
interface, because `poll` is not supposed to read data, but the async
`ReadFile` above *might* read some. So we need to create a buffer for this
data.

Later I noticed that the `ReadFile` documentation actually says this about
the `lpNumberOfBytesRead` argument:

> Use NULL for this parameter if this is an asynchronous operation to
> avoid potentially erroneous results.

While it does not details what errors might happen, and we have never seen
actually seen any such errors, this is a hint that if we set this argument
to `NULL`, then we can force `ReadFile` to be asyncronous and not return
any data. We already use this in `processx`, but the buffers have not been
eliminated yet, unless https://github.com/r-pkgs/processx/issues/57
states otherwise.

`read_pending` is true (non-zero) if there is a pending read on the file.

`tail` contains the last character read, see the Unix part above for why
this is necessary and how it is used.

#### Connections

We set up R connections to the read ends of the pipes. These are
non-blocking connections. Everything that we discussed about connections
in the Unix part, also applies here.

#### Polling for I/O

Polling for I/O is difficult on Windows, because Windows does not provide
a `poll` primitive, so we had to build it for ourselves. We implement
polling the standard output and/or error of a single process, and also
polling for multiple processes. In general the polling goes like this:

1. We see if there is anything to poll. E.g. if the process(es) have no
   open pipes, then there is nothing to poll.
2. We check if there is anything in any of the pipe buffers. (See above
   for why we are buffering.)
3. For each pipe that does not have I/O pending we start an async read.
   Currently, async reads might return synchronously (again, see above),
   if this happens, then we are done, we have some data.
4. Otherwise we wait on the `OVERLAPPED` events using
   `WaitForMultipleObjects`.

### Waiting with a timeout

This is actually easy on Windows, because the wait functions natively
support timeouts.

### Interruptible polling and waiting

We use the same strategy as on Unix. We wait for short time intervals,
and check for interrupts.

### Unloading the package

This does not seem to be a problem on windows, so we don't do anything
special here. Still in the future we will implement a procedure that
kills processes on unload, similarly to Unix:
https://github.com/r-pkgs/processx/issues/58
