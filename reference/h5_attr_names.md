# List HDF5 Attributes

Lists the names of attributes attached to a specific HDF5 object.

## Usage

``` r
h5_attr_names(file, name = "/")
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The path to the object (dataset or group) to query. Use `/` for the
  file's root attributes.

## Value

A character vector of attribute names.

## See also

[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

h5_write(1:10,          file, "data")
h5_write(I("meters"),   file, "data", attr = "unit")
h5_write(I(Sys.time()), file, "data", attr = "timestamp")

h5_attr_names(file, "data") # "unit" "timestamp"
#> [1] "unit"      "timestamp"

unlink(file)
```
