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

## Examples

``` r
file <- tempfile(fileext = ".h5")

# Create nested structure
h5_write(file, "group1/data1", 1)
#> NULL
h5_write(file, "group1/subgroup/data2", 2)
#> NULL
h5_write(file, "group2/data3", 3)
#> NULL

# List everything (Recursive)
h5_ls(file)
#> [1] "group1"                "group1/data1"          "group1/subgroup"      
#> [4] "group1/subgroup/data2" "group2"                "group2/data3"         

# List top level only
h5_ls(file, recursive = FALSE)
#> [1] "group1" "group2"

# List inside a specific group
h5_ls(file, "group1")
#> [1] "data1"          "subgroup"       "subgroup/data2"

unlink(file)
```
