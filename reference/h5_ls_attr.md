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

## See also

[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md)
