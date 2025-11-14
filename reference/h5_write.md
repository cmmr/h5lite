# Write a Dataset to HDF5

Writes an R object to an HDF5 file as a dataset. The file is created if
it does not exist. Handles dimension transposition automatically.

## Usage

``` r
h5_write(
  file,
  name,
  data,
  dtype = typeof(data),
  dims = length(data),
  compress = TRUE
)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset (e.g., "/data/matrix").

- data:

  The R object to write. Supported: `numeric`, `integer`, `logical`,
  `character`, `raw`.

- dtype:

  The target HDF5 data type. Defaults to `typeof(data)`. Options:
  "double", "integer", "logical", "character", "opaque", "float", etc.

- dims:

  An integer vector specifying dimensions, or `NULL` for a scalar.
  Defaults to `dim(data)` if it exists, or `length(data)` otherwise.

- compress:

  A logical or an integer from 0-9. If `TRUE` (default), compression
  level 5 is used. If `FALSE` or `0`, no compression is used. An integer
  `1-9` specifies the zlib compression level directly.

## Examples

``` r
file <- tempfile(fileext = ".h5")

# 1. Write a vector as a double
h5_write(file, "vec_double", c(1.5, 2.5, 3.5))
#> NULL

# 2. Write integers with compression
h5_write(file, "vec_int_compressed", 1:1000, dtype = "integer", compress = TRUE)
#> NULL

# 3. Write integers, enforcing integer storage on disk (uncompressed)
h5_write(file, "vec_int", 1:10, dtype = "integer")
#> NULL

# 4. Write a 3D array (uncompressed)
arr <- array(1:24, dim = c(2, 3, 4))
h5_write(file, "3d_array", arr)
#> NULL

# 5. Write a raw vector (as 1-byte OPAQUE)
h5_write(file, "raw_data", as.raw(c(0x01, 0xFF, 0x10)), dtype = "opaque")
#> NULL

# Verify types
h5_ls(file, recursive = TRUE)
#> [1] "3d_array"           "raw_data"           "vec_double"        
#> [4] "vec_int"            "vec_int_compressed"
h5_typeof(file, "raw_data") # "OPAQUE"
#> [1] "OPAQUE"

unlink(file)
```
