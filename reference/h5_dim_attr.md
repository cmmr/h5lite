# Get HDF5 Attribute Dimensions

Returns the dimensions of an attribute.

## Usage

``` r
h5_dim_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object attached to.

- attribute:

  Name of the attribute.

## Value

An integer vector of dimensions, or `integer(0)` for scalars.

## See also

[`h5_dim()`](https://cmmr.github.io/h5lite/reference/h5_dim.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)

h5_write_attr(file, "data", "vec_attr", 1:10)
h5_dim_attr(file, "data", "vec_attr") # 10
#> [1] 10

unlink(file)
```
