# Inspect HDF5 Dataset Creation Properties

Retrieves the Dataset Creation Property List (DCPL) details including
storage layout, chunk dimensions, and a detailed list of all applied
filters.

## Usage

``` r
h5_inspect(file, name)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The full path of the dataset to inspect.

## Value

An object of class `inspect` (a named list) containing:

- layout:

  A string indicating storage layout (e.g., "chunked", "contiguous").

- chunk_dims:

  A numeric vector of chunk dimensions, or `NULL` if not chunked.

- filters:

  A list describing each filter applied.

## Details

ZFP can't compress chunks with no dimension longer than one (such as a
single value) or more than four.
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md) uses
the default pipeline for them, but in files from other software ZFP may
have declined such a dataset: every chunk is stored uncompressed, and
[`print()`](https://rdrr.io/r/base/print.html) shows the filter as
`zfp (declined: stored uncompressed)`. With `hdf5lib` 2.2.0.1 or later,
Blosc2's ZFP codecs likewise decline chunks of fewer than four values,
shown as, e.g., `blosc2 [zfp-acc] (declined: stored uncompressed)`.

## Examples

``` r
file <- tempfile(fileext = ".h5")

compress <- h5_compression('lz4-9', int_packing = TRUE, checksum = TRUE)
h5_write(matrix(5001:5100, 10, 10), file, "packed_mtx", compress = compress)
h5_inspect(file, "packed_mtx")
#> <HDF5 Dataset Properties>
#>   Type:    uint16              Size:    200.00 B
#>   Layout:  chunked             Disk:    120.00 B
#>   Chunks:  [10 x 10]           Ratio:   1.67x
#>   Pipeline: scaleoffset -> lz4 -> fletcher32 

mtx <- matrix(rnorm(1000), 100, 10)
h5_write(mtx, file, "float_mtx", compress = 'blosc2-zfp-prec-3')
res <- h5_inspect(file, "float_mtx")
print(res)
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    7.81 KB
#>   Layout:  chunked             Disk:    1.48 KB
#>   Chunks:  [100 x 10]          Ratio:   5.29x
#>   Pipeline: blosc2 [zfp-prec] 

# Print the raw cd_values for blosc2
dput(res$filters[[1]]$cd_values)
#> c(2987393793, 0, 8, 8000, 5, 0, 34, 2, 100, 10)

unlink(file)
```
