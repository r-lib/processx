


# processx

> Execute and Control System Processes

[![Linux Build Status](https://travis-ci.org/r-pkgs/processx.svg?branch=master)](https://travis-ci.org/r-pkgs/processx)
[![Windows Build status](https://ci.appveyor.com/api/projects/status/15sfg3l9mm4aseyf/branch/master?svg=true)](https://ci.appveyor.com/project/gaborcsardi/processx)
[![](https://www.r-pkg.org/badges/version/processx)](https://www.r-pkg.org/pkg/processx)
[![CRAN RStudio mirror downloads](https://cranlogs.r-pkg.org/badges/processx)](https://www.r-pkg.org/pkg/processx)
[![Coverage Status](https://img.shields.io/codecov/c/github/r-pkgs/processx/master.svg)](https://codecov.io/github/r-pkgs/processx?branch=master)

Portable tools to run system processes in the background,
read their standard output and error, kill and restart them.

`processx` can poll the standard output and error of a single process,
or multiple processes, using the operating system's polling and waiting
facilities, with a timeout.

---

   * [Features](#features)
   * [Installation](#installation)
   * [Usage](#usage)
      * [Runing an external process](#runing-an-external-process)
         * [Errors](#errors)
         * [Showing output](#showing-output)
         * [Spinner](#spinner)
         * [Callbacks for I/O](#callbacks-for-io)
      * [Managing external processes](#managing-external-processes)
         * [Starting processes](#starting-processes)
         * [Killing and restarting a process](#killing-and-restarting-a-process)
         * [Standard output and error](#standard-output-and-error)
         * [End of output](#end-of-output)
         * [Polling the standard output and error](#polling-the-standard-output-and-error)
         * [Polling multiple processes](#polling-multiple-processes)
         * [Waiting on a process](#waiting-on-a-process)
         * [Exit statuses](#exit-statuses)
         * [Errors](#errors-1)
   * [License](#license)

## Features

* Start system processes in the background and find their
  process id.
* Read the standard output and error, using non-blocking R connection
  objects.
* Poll the standard output and error connections of a single process or
  multiple processes.
* Check if a background process is running.
* Wait on a background process.
* Get the exit status of a background process, if it has already
  finished.
* Kill background processes, together with their children.
* Kill background process, when its associated object is garbage
  collected.
* Restart background processes.
* Portable, works on Linux, macOS and Windows.
* Lightweight, it only depends on the also lightweight
  `R6`, `assertthat`, `crayon` and `debugme` packages.

## Installation


```r
source("https://install-github.me/r-pkgs/processx")
```

## Usage

> Note: the following external commands are usually present in macOS and
> Linux systems, but not necessarily on Windows.


```r
library(processx)
```

### Runing an external process

`processx` provides two ways to start processes. The first one
requires a single command, and a character vector of arguments.
You don't need to quote the command or the arguments, as they are
passed directly to the operating system, without an intermediate shell.


```r
run("echo", "Hello R!")
```

```
#> $status
#> [1] 0
#> 
#> $stdout
#> [1] "Hello R!\n"
#> 
#> $stderr
#> [1] ""
#> 
#> $timeout
#> [1] FALSE
```

The other way is to supply a full shell command line via the
`commandline` argument:


```r
run(commandline = "echo Hello R!")
```

```
#> $status
#> [1] 0
#> 
#> $stdout
#> [1] "Hello R!\n"
#> 
#> $stderr
#> [1] ""
#> 
#> $timeout
#> [1] FALSE
```

This methods starts up a shell, i.e. on Unix-like systems it runs
`sh -c <command>` and on Windows `cmd /c <command>`. (If you need a
different shell, then specify that directly in the `command` argument,
i.e. use the `command` + `args` form.

#### Errors

By default `run` throws an error if the process exits with a non-zero
status code. To avoid this, specify `error_on_status = FALSE`:


```r
run(commandline = "echo error >&2; exit 2", error_on_status = FALSE)
```

```
#> $status
#> [1] 2
#> 
#> $stdout
#> [1] ""
#> 
#> $stderr
#> [1] "error\n"
#> 
#> $timeout
#> [1] FALSE
```

#### Showing output

To show the output of the process on the screen, use the `echo` argument.
Note that the order of `stdout` and `stderr` lines may be incorrect,
because they are coming from two different connections.


```r
result <- run(
  commandline = "echo out; echo err 1>&2; echo out again",
  echo = TRUE)
```

```
#> out
#> out again
#> err
```

If you have a terminal that support ANSI colors, then the standard error
output is shown in red.

The standard output and error are still included in the result of the
`run()` call:


```r
result
```

```
#> $status
#> [1] 0
#> 
#> $stdout
#> [1] "out\nout again\n"
#> 
#> $stderr
#> [1] "err\n"
#> 
#> $timeout
#> [1] FALSE
```

Note that `run` is different from `system`, and it always shows the output
of the process on R's proper standard output, instead of writing to the
terminal directly. This means for example that you can capture the output
with `capture.output` or use `sink`, etc.:


```r
out1 <- capture.output(r1 <- system("ls"))
out2 <- capture.output(r2 <- run("ls", echo = TRUE))
```


```r
out1
```

```
#> character(0)
```

```r
out2
```

```
#>  [1] "DESCRIPTION"  "LICENSE"      "Makefile"     "NAMESPACE"   
#>  [5] "NEWS.md"      "R"            "README.Rmd"   "README.md"   
#>  [9] "appveyor.yml" "inst"         "man"          "src"         
#> [13] "tests"
```

#### Spinner

The `spinner` option of `run` puts a calming spinner to the terminal
while the background program is running. The spinner is always shown in the
first character of the last line, so you can make it work nicely with the
regular output of the background process if you like. E.g. try this in your
R terminal:

```
result <- run(
  commandline = paste(
    "printf '  foo';",
    "sleep 1;",
	"printf '\r  bar';",
	"sleep 1;",
	"printf '\rX foobar\n'"),
  echo = TRUE, spinner = TRUE)
```

#### Callbacks for I/O

`run` can call an R function for each line of the standard output or
error of the process, just supply the `stdout_line_callback` or the
`stderr_line_callback` arguments. The callback functions take two
arguments, the first one is a character scalar, the output line. The
second one is the `process` object that represents the background
process. (See more below about `process` objects.) You can manipulate
this object in the callback, if you want. For example you can kill it in
response to an error or some text on the standard output:


```r
cb <- function(line, proc) {
  cat("Got:", line, "\n")
  if (line == "done") proc$kill()
}
result <- run(
  commandline = paste(
    "echo this; echo that; echo done;",
    "echo still here;",
	"sleep 10; echo dead by now"),
  stdout_line_callback = cb,
  error_on_status = FALSE,
)
```

```
#> Got: this 
#> Got: that 
#> Got: done 
#> Got: still here
```

```r
result
```

```
#> $status
#> [1] -9
#> 
#> $stdout
#> [1] "this\nthat\ndone\nstill here\n"
#> 
#> $stderr
#> [1] ""
#> 
#> $timeout
#> [1] FALSE
```

Keep in mind, that while the R callback is running, the background process
has not stopped, it is also running. In the previous example, whether
`still here` is printed or not depends on the scheduling of the
R process and the background process by the OS. Typically, it is printed,
because the R callback takes a while to run.

In addition to the line-oriented callbacks, the `stdout_callback` and
`stderr_callback` arguments can specify callback functions that are called
with output chunks instead of single lines. A chunk may contain multiple
lines (separated by `\n` or `\r\n`), or even incomplete lines.

### Managing external processes

If you need better control over possibly multiple background processes,
then you can use the R6 `process` class directly.

#### Starting processes

To start a new background process, create a new instance of the `process`
class. Similarly to `run`, the `process` constructor supports two
kinds of argument specifications. If `commandline` is specified, then
it is passed to a shell.


```r
p1 <- process$new("sleep", "20")
p2 <- process$new(commandline = "sleep 20")
```

#### Killing and restarting a process

A process can be killed via the `kill` method. This also kills
all child processes (unless they created a new process group on Unix,
or a new job object on Windows).


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
```

```
#> [1] TRUE
```

```r
p2$kill()
```

```
#> [1] TRUE
```

```r
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

Note that processes are finalized (and killed) automatically if the
corresponding `process` object goes out of scope, as soon as the object
is garbage collected by R:


```r
p <- process$new("sleep", "20")
rm(p)
gc()
```

```
#>          used (Mb) gc trigger (Mb) max used (Mb)
#> Ncells 303179 16.2     592000 31.7   460000 24.6
#> Vcells 500110  3.9    1023718  7.9   786411  6.0
```

Here, the direct call to the garbage collector kills the `sleep` process
as well. See the `cleaup` option if you want to avoid this behavior.

#### Standard output and error

By default the standard output and error of the processes are ignored.
You can set the `stdout` and `stderr` constructor arguments to a file name,
and then they are redirected there, or to `"|"`, and then `processx` creates
R connections to them.

The `read_output_lines` and `read_error_lines` methods can be used
to read from the standard output or error connections. They work the same
way as the `readLines` base function.

Alternatively, you can query the connections via the `get_output_connection`
and `get_error_connection` functions, and work with them directly.

Note, that the R connections have a buffer, which can fill up, if R does
not read out the output, and then the process will stop, until R reads the
connection and the buffer is freed.

> **Always make sure that you read out the standard output and/or error**
> **of the pipes, otherwise the background process will stop running!**

Note that the connections used for reading the output and error streams
are non-blocking text connections, so the read functions will return
immediately, even if there is no text to read from them.


```r
p <- process$new(commandline = "echo foo; >&2 echo bar; echo foobar",
                 stdout = "|", stderr = "|")
p$read_output_lines()
```

```
#> character(0)
```

```r
p$read_error_lines()
```

```
#> [1] "bar"
```

To check if there is anything available for reading on the standard output
or error streams, you can use the `is_incomplete_output()` and
`is_incomplete_error()` methods:


```r
p <- process$new(commandline = "echo foo; sleep 2; echo bar", stdout = "|")

Sys.sleep(1)
## There must be output now
p$is_incomplete_output()
```

```
#> [1] TRUE
```

```r
p$read_output_lines()
```

```
#> [1] "foo"
```

```r
## There is no more output now
p$is_incomplete_output()
```

```
#> [1] TRUE
```

```r
p$read_output_lines()
```

```
#> character(0)
```

```r
Sys.sleep(2)
## There is output again
p$is_incomplete_output()
```

```
#> [1] TRUE
```

```r
p$read_output_lines()
```

```
#> [1] "bar"
```

```r
## There is no more output
p$is_incomplete_output()
```

```
#> [1] FALSE
```

```r
p$read_output_lines()
```

```
#> character(0)
```

#### End of output

There is no standard way in R to signal the end of a connection,
unfortunately. Most R I/O is blocking, and the end of file is reached when
nothing can be read from the connection. This clearly does not work for
non-blocking connections.

For `processx` standard output and error streams, you can use the
`is_incomplete_output` and `is_incomplete_error` functions to check if
there is any chance that more output will arrive on them later.

#### Polling the standard output and error

The `poll_io` method waits for data on the standard output and/or error
of a process. It will return if any of the following events happen:

* data is available on the standard output of the process (assuming there is
  an R connection to the standard output).
* data is available on the standard error of the proces (assuming the is
  an R connection to the standard error).
* The process has finished and the standard output and/or error connections
  were closed on the other end.
* The specified timeout period expired.

For example the following code waits about a second for output.


```r
p <- process$new(commandline = "sleep 1; ls", stdout = "|")

## No output yet
p$read_output_lines()
```

```
#> character(0)
```

```r
## Wait at most 5 sec
p$poll_io(5000)
```

```
#>   output    error 
#>  "ready" "nopipe"
```

```r
## There is output now
p$read_output_lines()
```

```
#>  [1] "DESCRIPTION"  "LICENSE"      "Makefile"     "NAMESPACE"   
#>  [5] "NEWS.md"      "R"            "README.Rmd"   "README.md"   
#>  [9] "appveyor.yml" "inst"         "man"          "src"         
#> [13] "tests"
```

#### Polling multiple processes

If you need to manage multiple background processes, and need to wait
for output from all of them, `processx` defines a `poll` function that
does just that. It is similar to the `poll_io` method, but it takes
multiple process objects, and returns as soon as one of them have data
on standard output or error, or a timeout expires. Here is an example:


```r
p1 <- process$new(commandline = "sleep 1; ls", stdout = "|")
p2 <- process$new(commandline = "sleep 2; ls 1>&2", stderr = "|")

## After 100ms no output yet
poll(list(p1 = p1, p2 = p2), 100)
```

```
#> $p1
#>    output     error 
#> "timeout"  "nopipe" 
#> 
#> $p2
#>    output     error 
#>  "nopipe" "timeout"
```

```r
## But now we surely have something
poll(list(p1 = p1, p2 = p2), 1000)
```

```
#> $p1
#>   output    error 
#>  "ready" "nopipe" 
#> 
#> $p2
#>   output    error 
#> "nopipe" "silent"
```

```r
p1$read_output_lines()
```

```
#>  [1] "DESCRIPTION"  "LICENSE"      "Makefile"     "NAMESPACE"   
#>  [5] "NEWS.md"      "R"            "README.Rmd"   "README.md"   
#>  [9] "appveyor.yml" "inst"         "man"          "src"         
#> [13] "tests"
```

```r
## Done with p1
close(p1$get_output_connection())

## The second process should have data on stderr by now
poll(list(p1 = p1, p2 = p2), 5000)
```

```
#> $p1
#>   output    error 
#> "closed" "nopipe" 
#> 
#> $p2
#>   output    error 
#> "nopipe"  "ready"
```

```r
p2$read_error_lines()
```

```
#>  [1] "DESCRIPTION"  "LICENSE"      "Makefile"     "NAMESPACE"   
#>  [5] "NEWS.md"      "R"            "README.Rmd"   "README.md"   
#>  [9] "appveyor.yml" "inst"         "man"          "src"         
#> [13] "tests"
```

#### Waiting on a process

As seen before, `is_alive` checks if a process is running. The `wait`
method can be used to wait until it has finished (or a specified timeout
expires).. E.g. in the following code `wait` needs to wait about 2 seconds
for the `sleep` shell command to finish.


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
#> [1] "2017-05-18 14:16:55 BST"
```

```r
p$wait()
Sys.time()
```

```
#> [1] "2017-05-18 14:16:57 BST"
```

It is safe to call `wait` multiple times:


```r
p$wait() # already finished!
```

#### Exit statuses

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

#### Errors

Errors are typically signalled via non-zero exits statuses. The `processx`
constructor fails if the external program cannot be started,
but it does not deal with errors that happen after the
program has successfully started running.


```r
p <- process$new("nonexistant-command-for-sure")
```

```
#> Error in process_initialize(self, private, command, args, commandline, : processx error
```


```r
p2 <- process$new(commandline = "sleep 1; command-does-not-exist-right")
p2$wait()
p2$get_exit_status()
```

```
#> [1] 127
```

## License

MIT © Mango Solutions, RStudio, Gábor Csárdi
