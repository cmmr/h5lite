# Get HDF5 Attribute Type

Returns the low-level HDF5 storage type of an attribute.

## Usage

``` r
h5_typeof_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  Name of the object attached to.

- attribute:

  Name of the attribute.

## Value

A string representing the HDF5 storage type.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)
#> NULL

h5_write_attr(file, "data", "meta", "info", dims = NULL)
#> NULL
h5_typeof_attr(file, "data", "meta") # "STRING"
#> [1] "STRING"

unlink(file)
```
