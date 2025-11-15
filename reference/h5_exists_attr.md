# Check if an HDF5 Attribute Exists

Checks for the existence of an attribute on an HDF5 object without
raising an error if it does not exist.

## Usage

``` r
h5_exists_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The path to the object (dataset or group).

- attribute:

  The name of the attribute to check.

## Value

A logical value: `TRUE` if the attribute exists, `FALSE` otherwise.

## See also

[`h5_exists()`](https://cmmr.github.io/h5lite/reference/h5_exists.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "my_data", 1)
h5_write_attr(file, "my_data", "units", "meters")

h5_exists_attr(file, "my_data", "units") # TRUE
#> [1] TRUE
h5_exists_attr(file, "my_data", "nonexistent_attr") # FALSE
#> [1] FALSE

unlink(file)
```
