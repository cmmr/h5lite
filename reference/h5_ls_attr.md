# List HDF5 Attributes

Lists the names of attributes attached to a specific HDF5 object.

## Usage

``` r
h5_ls_attr(file, name)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The path to the object (dataset or group) to query. Use "/" for the
  file's root attributes.

## Value

A character vector of attribute names.

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(file, "data", 1)
#> NULL

h5_write_attr(file, "data", "a1", 1, dims = NULL)
#> NULL
h5_write_attr(file, "data", "a2", 2, dims = NULL)
#> NULL

h5_ls_attr(file, "data")
#> [1] "a1" "a2"
unlink(file)
```
