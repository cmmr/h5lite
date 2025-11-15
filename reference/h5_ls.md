# List HDF5 Objects

Lists the names of objects (datasets and groups) within an HDF5 file.

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

A character vector of object names (relative paths).
