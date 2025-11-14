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

Integer vector of dimensions, or `integer(0)` for scalars.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)
#> NULL

h5_write_attr(file, "data", "vec_attr", 1:10)
#> NULL
h5_dim_attr(file, "data", "vec_attr") # 10
#> [1] 10

unlink(file)
```
