# Delete an HDF5 Attribute

Deletes an attribute from an object.

## Usage

``` r
h5_delete_attr(file, name, attribute)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The path to the object (dataset or group).

- attribute:

  The name of the attribute to delete.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)
#> NULL
h5_write_attr(file, "data", "attr1", 123, dims = NULL)
#> NULL
h5_ls_attr(file, "data") # "attr1"
#> [1] "attr1"

h5_delete_attr(file, "data", "attr1")
#> NULL
h5_ls_attr(file, "data") # character(0)
#> character(0)
unlink(file)
```
