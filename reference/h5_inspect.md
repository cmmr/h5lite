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
#> <HDF5 Dataset Properties>
#>   Type:    float64             Size:    7.81 KB
#>   Layout:  chunked             Disk:    1.49 KB
#>   Chunks:  [100 x 10]          Ratio:   5.23x
#>   Pipeline: blosc2 [zfp-prec]

# Print the raw cd_values for blosc2
dput(res$filters[[1]]$cd_values)
#> c(2L, 0L, 8L, 8000L, 3L, 0L, 34L, 2L, 100L, 10L, 3L)
#> c(2L, 0L, 8L, 8000L, 3L, 0L, 34L, 2L, 100L, 10L, 3L)

unlink(file)
```
