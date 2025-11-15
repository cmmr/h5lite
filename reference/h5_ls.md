# List HDF5 Objects

Lists the names of objects (datasets and groups) within an HDF5 file or
group.

## Usage

``` r
h5_ls(file, name = "/", recursive = TRUE)
```

## Arguments

- file:

  Path to the HDF5 file.

- name:

  The group path to start listing from. Defaults to the root group "/".

- recursive:

  If `TRUE` (default), lists all objects found recursively under `name`.
  If `FALSE`, lists only the immediate children of `name`.

## Value

A character vector of object names. If `name` is `/` (the default), the
paths are relative to the root of the file. If `name` is another group,
the paths are relative to that group.

## See also

[`h5_ls_attr()`](https://cmmr.github.io/h5lite/reference/h5_ls_attr.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create some nested objects
h5_write(file, "g1/d1", 1)
h5_write(file, "g1/g2/d2", 2)

# List recursively from the root (default)
h5_ls(file) # c("g1", "g1/d1", "g1/g2", "g1/g2/d2")
#> [1] "g1"       "g1/d1"    "g1/g2"    "g1/g2/d2"

# List recursively from a subgroup
h5_ls(file, name = "g1") # c("d1", "g2", "g2/d2")
#> [1] "d1"    "g2"    "g2/d2"

unlink(file)
```
