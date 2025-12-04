# Display the Structure of an HDF5 Object

Recursively prints a summary of an HDF5 group or dataset, similar to the
structure of `h5ls -r`. It displays the nested structure, object types,
dimensions, and attributes.

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

This function is called for its side-effect of printing to the console
and returns `NULL` invisibly.

## Details

This function provides a quick and convenient way to inspect the
contents of an HDF5 file. It performs a recursive traversal of the file
from the C-level and prints a formatted summary to the R console.

This function **does not read any data** into R. It only inspects the
metadata (names, types, dimensions) of the objects in the file, making
it fast and memory-safe for arbitrarily large files.

## See also

[`h5_ls()`](https://cmmr.github.io/h5lite/reference/h5_ls.md),
[`h5_ls_attr()`](https://cmmr.github.io/h5lite/reference/h5_ls_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create a nested structure
h5_write(file, "/config/version", I(1.2))
h5_write(file, "/data/matrix", matrix(1:4, 2, 2))
h5_write_attr(file, "/data/matrix", "title", "my matrix")

# Display the structure of the entire file
h5_str(file)
#> Listing contents of: /tmp/Rtmp915GTO/file19c0e4e799f.h5
#> Root group: /
#> ----------------------------------------------------------------
#> Type            Name
#> ----------------------------------------------------------------
#> Group        config
#> float64      config/version
#> Group        data
#> uint8[2,2]   data/matrix
#> string[1]    data/matrix @title

unlink(file)
```
