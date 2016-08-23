


# process

> Execute and Control System Processes

[![Linux Build Status](https://travis-ci.org/gaborcsardi/process.svg?branch=master)](https://travis-ci.org/gaborcsardi/process)
[![Windows Build status](https://ci.appveyor.com/api/projects/status/github/gaborcsardi/process?svg=true)](https://ci.appveyor.com/project/gaborcsardi/process)
[![](http://www.r-pkg.org/badges/version/process)](http://www.r-pkg.org/pkg/process)
[![CRAN RStudio mirror downloads](http://cranlogs.r-pkg.org/badges/process)](http://www.r-pkg.org/pkg/process)

Portable tools to run system processes in the background,
read their standard output and error, kill and restart them.

---

  - [Features](#features)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Starting processes](#starting-processes)
    - [Killing and restarting a process](#killing-and-restarting-a-process)
    - [Standard output and error](#standard-output-and-error)
    - [End of output](#end-of-output)
    - [Waiting on a process](#waiting-on-a-process)
	- [Exit statuses](#exit-statuses)
	- [Errors](#errors)
  - [License](#license)

## Features

* Start system processes in the background.
* Check if a background process is running.
* Wait on a background process.
* Get the exit status of a background process, if it has already
  finished.
* Kill background processes, together with their children.
* Restart background processes.
* Read the standard output and error, using non-blocking connections.
* Portable, works on Linux, macOS and Windows.
* Lightweight, it only depends on the also lightweight
  [R6](http://r-pkg.org/pkg/R6) package.
* Contains no compiled code, so it is easy to install.

## Installation


```r
source("https://install-github.me/gaborcsardi/process")
```

## Usage

Note: the following external commands are usually present in macOS and
Linux systems, but not necessarily on Windows.


```r
library(process)
```

### Starting processes

`process` provides two ways to start processes. The first one
requires a single command, and a character vector of arguments.
Both the command and the arguments will be shell quoted, so it is safe
to include spaces and other special characters:


```r
p1 <- process$new("sleep", "20")
```

The other way is to supply a full shell command line via the
`commandline` argument:


```r
p2 <- process$new(commandline = "sleep 20")
```

Both methods will run the specified command or command line via the
`pipe` base R function, which currently uses a shell to start them.

### Killing and restarting a process

A process can be killed via the `kill` method. This also kills
all child processes.


```r
p1$is_alive()
```

```
#> [1] TRUE
```

```r
p2$is_alive()
```

```
#> [1] TRUE
```

```r
p1$kill()
p2$kill()
p1$is_alive()
```

```
#> [1] FALSE
```

```r
p2$is_alive()
```

```
#> [1] FALSE
```

A process can be restarted via `restart`. This works if the process
has been killed, if it has finished regularly, or even if it is running
currently. If it is running, then it will be killed first.


```r
p1$restart()
p1$is_alive()
```

```
#> [1] TRUE
```

### Standard output and error

By default the standard output and error of the processes are redirected
to temporary files. You can set the `stdout` and `stderr` constructor
arguments to `FALSE` to force discarding them, in case you have a long
running process with a lot of output. You can also set them to file names,
if you want the output and/or error streams in some specific files.

The `read_output_lines` and `read_error_lines` methods can be used
to read the standard output or error. They work the same way as the
`readLines` base function.

Note that the connections used for reading the output and error streams
are non-blocking text connections, so the read functions will return
immediately, even if there is no text to read from them.


```r
p <- process$new(commandline = "echo foo; >&2 echo bar; echo foobar")
p$read_output_lines()
```

```
#> [1] "foo"    "foobar"
```

```r
p$read_error_lines()
```

```
#> [1] "bar"
```

### End of output

TODO


### Waiting on a process

As seen before, `is_alive` checks if a process is running. The `wait`
method can be used to wait until it has finished. E.g. in the following
code `wait` needs to wait about 2 seconds for the `sleep` shell command
to finish.


```r
p <- process$new(commandline = "sleep 2")
p$is_alive()
```

```
#> [1] TRUE
```

```r
Sys.time()
```

```
#> [1] "2016-08-22 15:18:20 BST"
```

```r
p$wait()
Sys.time()
```

```
#> [1] "2016-08-22 15:18:22 BST"
```

It is safe to call `wait` multiple times:


```r
p$wait() # already finished!
```

### Exit statuses

After a process has finished, its exit status can be queried via the
`get_exit_status` method. If the process is still running, then this
method returns `NULL`.


```r
p <- process$new(commandline = "sleep 2")
p$get_exit_status()
```

```
#> NULL
```

```r
p$wait()
p$get_exit_status()
```

```
#> [1] 0
```

Note that even if the process has finished, `get_exit_status` might report
`NULL` if `wait` was not called. If you know that the process has finished,
call `wait` first, and only then `get_exit_status`.


```r
p <- process$new(commandline = "true")

# wait until it surely finishes
Sys.sleep(1)
p$is_alive()
```

```
#> [1] FALSE
```

```r
p$get_exit_status()
```

```
#> NULL
```

```r
p$wait()
p$get_exit_status()
```

```
#> [1] 0
```

### Errors

Errors are typically signalled via non-zero exits statuses. `process`
currently has no special behavior to handle errors.

If you want to make sure that the process has started successfully,
check that it is running via `is_alive()`, and if it is not, then check
its exit status (after calling `wait`).


```r
p <- process$new("nonexistant-command-for-sure")
if (!p$is_alive()) {
  p$wait()
  if (p$get_exit_status() != 0) {
    stop("nonexistant-command-for-sure failed")
  }
}
```

```
#> Error in eval(expr, envir, enclos): nonexistant-command-for-sure failed
```

## License

MIT © Gábor Csárdi
