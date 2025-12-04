# Working with Matrices and Arrays

``` r
library(h5lite)

# We'll use a temporary file for this guide.
file <- tempfile(fileext = ".h5")
```

## Introduction

Matrices and multi-dimensional arrays are workhorses of data analysis in
R. `h5lite` is designed to make saving and loading these objects to HDF5
files as seamless as possible, automatically handling dimensions and
data layout.

This vignette covers the basics of working with matrices and arrays, and
then dives into two important technical details: the `dimnames`
limitation and the automatic handling of row-major vs. column-major data
ordering.

For details on other data structures, see
[`vignette("atomic-vectors")`](https://cmmr.github.io/h5lite/articles/atomic-vectors.md)
and
[`vignette("data-frames")`](https://cmmr.github.io/h5lite/articles/data-frames.md).

## 1. Writing and Reading Matrices

Writing a matrix or array is as simple as calling
[`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md).
`h5lite` will automatically detect the dimensions of your R object and
create an HDF5 dataset with a corresponding dataspace.

``` r
# A simple 2x3 matrix
my_matrix <- matrix(1:6, nrow = 2, ncol = 3)
print(my_matrix)
#>      [,1] [,2] [,3]
#> [1,]    1    3    5
#> [2,]    2    4    6

h5_write(file, "my_matrix", my_matrix)
```

You can verify the dimensions of the on-disk dataset using
[`h5_dim()`](https://cmmr.github.io/h5lite/reference/h5_dim.md).

``` r
h5_dim(file, "my_matrix")
#> [1] 2 3
```

When you read the data back with
[`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md),
`h5lite` restores the dimensions, giving you an identical R matrix.

``` r
read_matrix <- h5_read(file, "my_matrix")

all.equal(my_matrix, read_matrix)
#> [1] TRUE
```

The same process works for higher-dimensional arrays.

``` r
my_array <- array(1:24, dim = c(2, 3, 4))
h5_write(file, "my_array", my_array)

h5_dim(file, "my_array")
#> [1] 2 3 4
```

## The `dimnames` Limitation

A crucial limitation to be aware of involves `dimnames` (the row and
column names of a matrix). HDF5 does not have a native way to store
these, and R implements them as a `list` attribute.

The `h5lite` function
[`h5_write_attr()`](https://cmmr.github.io/h5lite/reference/h5_write_attr.md)
cannot write list-like attributes. Therefore, attempting to write a
matrix with `dimnames` while `attrs = TRUE` will result in an error.

``` r
named_matrix <- matrix(1:4, nrow = 2, ncol = 2,
                       dimnames = list(c("row1", "row2"), c("col1", "col2")))

str(attributes(named_matrix))
#> List of 2
#>  $ dim     : int [1:2] 2 2
#>  $ dimnames:List of 2
#>   ..$ : chr [1:2] "row1" "row2"
#>   ..$ : chr [1:2] "col1" "col2"

# This will fail because the 'dimnames' attribute is a list.
h5_write(file, "named_matrix", named_matrix, attrs = TRUE)
#> Error in validate_attrs(data, attrs): Attribute 'dimnames' cannot be written to HDF5 because its type ('list') is not supported. Only atomic vectors and factors can be written as attributes.
```

### Workaround

The solution is to either remove the `dimnames` before writing or, more
simply, write with `attrs = FALSE` (the default). This will successfully
write the matrix data but will discard the `dimnames`.

``` r
# This works, but the dimnames are not saved.
h5_write(file, "named_matrix", named_matrix, attrs = FALSE)

read_named_matrix <- h5_read(file, "named_matrix")

# The data is correct, but the names are gone.
print(read_named_matrix)
#>      [,1] [,2]
#> [1,]    1    3
#> [2,]    2    4
dimnames(read_named_matrix)
#> NULL
```

## Advanced Details: Row-Major vs. Column-Major Order

One of the most common sources of error when using HDF5 with R is
managing the different data layouts.

- **R** stores matrices and arrays in **column-major** order. In memory,
  the elements of the first column are contiguous, followed by the
  second column, and so on.
- **HDF5** (along with C, C++, and Python’s NumPy) uses **row-major**
  order. The elements of the first row are contiguous in memory/on disk.

`h5lite` **completely automates the transposition** required to move
between these two layouts.

### How it Works

Consider our 2x3 `my_matrix`:

``` r
print(my_matrix)
#>      [,1] [,2] [,3]
#> [1,]    1    3    5
#> [2,]    2    4    6
```

- **On
  [`h5_write()`](https://cmmr.github.io/h5lite/reference/h5_write.md)**:
  The C-level code reads the R object’s column-major data
  (`1, 2, 3, 4, 5, 6`) and transposes it into a row-major buffer
  (`1, 3, 5, 2, 4, 6`) before writing it to the HDF5 file.
- **On
  [`h5_read()`](https://cmmr.github.io/h5lite/reference/h5_read.md)**:
  The C-level code reads the row-major data from the file and transposes
  it back into R’s native column-major layout.

This “it just works” behavior is a core design principle of `h5lite`. It
ensures that the matrix you read back is identical to the one you wrote,
without requiring you to perform manual array transpositions
([`aperm()`](https://rdrr.io/r/base/aperm.html)) or think about data
ordering. This is a significant convenience compared to lower-level HDF5
interfaces.

## Compression

For large matrices, using compression can significantly reduce file
size. Simply set `compress = TRUE` (which uses a default compression
level of 5) or specify an integer from 1-9.

`h5lite` automatically creates chunked storage when compression is
enabled, which is a prerequisite for HDF5 compression filters.

``` r
large_matrix <- matrix(rnorm(1e6), nrow = 1000)

# Write with default compression
h5_write(file, "large_matrix_compressed", large_matrix, compress = TRUE)

# Write without compression
h5_write(file, "large_matrix_uncompressed", large_matrix, compress = FALSE)

# Compare file sizes (in a real scenario, the compressed version would be smaller)
h5_ls(file, full.names = TRUE)
#> [1] "my_matrix"                 "my_array"                 
#> [3] "named_matrix"              "large_matrix_compressed"  
#> [5] "large_matrix_uncompressed"
```

> **Note:** For random data like in this example, compression is not
> very effective. It works best on data with repeating patterns or low
> entropy.

``` r
# Clean up the temporary file
unlink(file)
```
