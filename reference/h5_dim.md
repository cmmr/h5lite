# Get HDF5 Object Dimensions

Returns the dimensions of a dataset as an integer vector. These
dimensions match the R-style (column-major) interpretation.

## Usage

``` r
h5_dim(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the dataset.

## Value

An integer vector of dimensions, or `integer(0)` for scalars.

## See also

[`h5_dim_attr()`](https://cmmr.github.io/h5lite/reference/h5_dim_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

mat <- matrix(1:10, nrow = 2, ncol = 5)
h5_write(file, "matrix", mat)

# Check dims without reading the whole dataset
h5_dim(file, "matrix") # Returns c(2, 5)
#> [1] 2 5

unlink(file)
```
