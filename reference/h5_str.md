# Display the Structure of an HDF5 Object

Recursively prints a summary of an HDF5 group or dataset, similar to
[`utils::str()`](https://rdrr.io/r/utils/str.html). It displays the
nested structure, object types, dimensions, and attributes.

## Usage

``` r
h5_str(file, name = "/")
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The name of the group or dataset to display. Defaults to the root
  group "/".

## Value

This function is called for its side effect of printing to the console
and returns `NULL` invisibly.

## Details

This function provides a quick and convenient way to inspect the
contents of an HDF5 file. It works by first reading the target object
and all its children into a nested R list using
[`h5_read_all`](https://cmmr.github.io/h5lite/reference/h5_read_all.md),
and then calling [`utils::str()`](https://rdrr.io/r/utils/str.html) on
the resulting R object.

Because this function reads the data into memory, it may be slow or
memory-intensive for very large files or groups.

## See also

[`h5_read_all()`](https://cmmr.github.io/h5lite/reference/h5_read_all.md),
[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a nested structure
h5_write(file, "/config/version", 1.2)
h5_write(file, "/data/matrix", matrix(1:4, 2, 2))

# Display the structure of the entire file
h5_str(file)
#> Listing contents of: /tmp/RtmpkohwDW/file190c70f691e6.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type         Name
#> ----------------------------------------------------------------
#> Group        config
#> float64[1]   config/version
#> Group        data
#> uint8[2,2]   data/matrix

unlink(file)
```
