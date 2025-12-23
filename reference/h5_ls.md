# List HDF5 Objects

Lists the names of objects (datasets and groups) within an HDF5 file or
group.

## Usage

``` r
h5_ls(file, name = "/", recursive = TRUE, full.names = FALSE, scales = FALSE)
```

## Arguments

- file:

  The path to the HDF5 file.

- name:

  The group path to start listing from. Defaults to the root group
  (`/`).

- recursive:

  If `TRUE` (default), lists all objects found recursively under `name`.
  If `FALSE`, lists only the immediate children.

- full.names:

  If `TRUE`, the full paths from the file's root are returned. If
  `FALSE` (the default), names are relative to `name`.

- scales:

  If `TRUE`, also returns datasets that are dimensions scales for other
  datasets.

## Value

A character vector of object names. If `name` is `/` (the default), the
paths are relative to the root of the file. If `name` is another group,
the paths are relative to that group (unless `full.names = TRUE`).

## See also

[`h5_attr_names()`](https://cmmr.github.io/h5lite/reference/h5_attr_names.md),
[`h5_str()`](https://cmmr.github.io/h5lite/reference/h5_str.md)

## Examples

``` r
file <- tempfile(fileext = ".h5")
h5_create_group(file, "foo/bar")
h5_write(1:5, file, "foo/data")

# List everything recursively
h5_ls(file)
#> [1] "foo"      "foo/bar"  "foo/data"

# List only top-level objects
h5_ls(file, recursive = FALSE)
#> [1] "foo"

# List relative to a sub-group
h5_ls(file, "foo")
#> [1] "bar"  "data"

unlink(file)
```
