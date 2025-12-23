# Get Dimensions of an HDF5 Object or Attribute

Returns the dimensions of a dataset or an attribute as an integer
vector. These dimensions match the R-style (column-major)
interpretation.

## Usage

``` r
h5_dim(file, name, attr = NULL)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  Name of the dataset or object.

- attr:

  The name of an attribute to check. If `NULL` (default), the function
  returns the dimensions of the object itself.

## Value

An integer vector of dimensions, or `integer(0)` for scalars.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(matrix(1:10, 2, 5), file, "matrix")
h5_dim(file, "matrix") # 2 5
#> [1] 2 5
unlink(file)
```
