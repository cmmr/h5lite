# Display the Structure of an HDF5 Object

Recursively prints a summary of an HDF5 group or dataset, similar to the
structure of `h5ls -r`. It displays the nested structure, object types,
dimensions, and attributes.

## Usage

``` r
h5_str(file, name = "/", attrs = TRUE)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The name of the group or dataset to display. Defaults to the root
  group "/".

- attrs:

  Set to `FALSE` to only groups and datasets. The default (`TRUE`) shows
  attributes as well.

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
[`h5_attr_names()`](https://cmmr.github.io/h5lite/reference/h5_attr_names.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_write(list(x = 1:10, y = matrix(1:9, 3, 3)), file, "group")
h5_write("metadata", file, "group", attr = "info")

# Print structure
h5_str(file)
#> /
#> └── group
#>     ├── @info <utf8 × 1>
#>     ├── x <int32 × 10>
#>     └── y <int32 × 3 × 3>

unlink(file)
```
