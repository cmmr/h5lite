# Set the Number of Threads

Sets how many threads `h5lite` uses for the work it can do in parallel.
Currently that is the Blosc and Blosc2 codecs (`"blosc1-..."` and
`"blosc2-..."`), which compress and decompress the blocks of each chunk
in parallel. Everything uses one thread unless you ask for more.

## Usage

``` r
h5_threads(n = NULL)
```

## Arguments

- n:

  The number of threads, from `1` to `256`, or `0` to return to the
  default. If `NULL` (the default), the setting is left unchanged.

## Value

With `n = NULL`, the number of threads `h5lite` will use. Otherwise, the
previous setting, invisibly (`0` if none had been made).

## Details

More threads help most when compression is slow, as with high Zstandard
levels, or when chunks are large. The setting applies to `h5lite` for
the rest of the R session.

The default is one thread, or the value of the `H5LITE_NTHREADS`
environment variable if it is set. Calling `h5_threads()` overrides it.

Threads need `hdf5lib` 2.2.0.1 or later. When `h5lite` is built with
`hdf5lib` 2.2.0.0, Blosc always uses one thread, whatever the setting.

CRAN allows packages to use at most two threads in their examples,
tests, and vignettes.

## See also

[`h5_compression()`](https://cmmr.github.io/h5lite/reference/h5_compression.md),
[`vignette('compression')`](https://cmmr.github.io/h5lite/articles/compression.md)

## Examples

``` r
h5_threads()      # 1
#> [1] 1

old <- h5_threads(2)
file <- tempfile(fileext = ".h5")
h5_write(rnorm(1e5), file, "x", compress = "blosc2-zstd-5")

h5_threads(old)   # Restore the previous setting
unlink(file)
```
