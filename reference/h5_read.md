# Read a Dataset from HDF5

Reads a dataset from an HDF5 file and returns it as an R object.

## Usage

``` r
h5_read(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset (e.g., "/data/matrix").

## Value

A `numeric`, `character`, or `raw` vector/array.

## Details

- Numeric datasets are read as `numeric` (double) to prevent overflow.

- String datasets are read as `character`.

- 1-byte `OPAQUE` datasets are read as `raw`.

Dimensions are preserved and transposed to match R's column-major order.

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write a matrix
mat <- matrix(1:12, nrow = 3, ncol = 4)
h5_write(file, "example_matrix", mat)
#> NULL

# Read it back
mat2 <- h5_read(file, "example_matrix")
print(mat2)
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    4    7   10
#> [2,]    2    5    8   11
#> [3,]    3    6    9   12

# Verify equality
all.equal(mat, mat2)
#> [1] TRUE

unlink(file)
```
