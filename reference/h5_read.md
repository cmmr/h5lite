# Read an HDF5 Dataset

Reads a dataset from an HDF5 file and returns it as an R object.

## Usage

``` r
h5_read(file, name, attrs = FALSE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset (e.g., "/data/matrix").

- attrs:

  Controls which HDF5 attributes are read and attached to the returned R
  object. Can be `FALSE` (the default, no attributes), `TRUE` (all
  attributes), a character vector of attribute names to include (e.g.,
  `c("info", "version")`), or a character vector of names to exclude,
  prefixed with `-` (e.g., `c("-class")`). Non-existent attributes are
  silently skipped.

## Value

A `numeric`, `character`, `factor`, or `raw` vector/array.

## Details

- Numeric datasets are read as `numeric` (double) to prevent overflow.

- String datasets are read as `character`.

- `ENUM` datasets are read as `factor`.

- 1-byte `OPAQUE` datasets are read as `raw`.

Dimensions are preserved and transposed to match R's column-major order.

## See also

[`h5_read_attr()`](https://cmmr.github.io/h5lite/reference/h5_read_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Write a matrix
mat <- matrix(1:12, nrow = 3, ncol = 4)
h5_write(file, "example_matrix", mat)
# Write a factor
fac <- factor(c("a", "b", "a", "c"))
h5_write(file, "example_factor", fac)

# Read it back
mat2 <- h5_read(file, "example_matrix")
fac2 <- h5_read(file, "example_factor")

# Print and verify
print(mat2)
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    4    7   10
#> [2,]    2    5    8   11
#> [3,]    3    6    9   12
all.equal(mat, mat2)
#> [1] TRUE

print(fac2)
#> [1] a b a c
#> Levels: a b c
all.equal(fac, fac2)
#> [1] TRUE

unlink(file)
```
