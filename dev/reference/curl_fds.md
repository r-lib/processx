# Create a pollable object from a curl multi handle's file descriptors

Create a pollable object from a curl multi handle's file descriptors

## Usage

``` r
curl_fds(fds)
```

## Arguments

- fds:

  A list of file descriptors, as returned by
  [`curl::multi_fdset()`](https://jeroen.r-universe.dev/curl/reference/multi.html).

## Value

Pollable object, that be used with
[`poll()`](http://processx.r-lib.org/dev/reference/poll.md) directly.
